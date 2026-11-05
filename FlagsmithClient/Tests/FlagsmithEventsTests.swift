//
//  FlagsmithEventsTests.swift
//  FlagsmithClientTests
//

@testable import FlagsmithClient
import XCTest

/// Records the batches sent to the events API, and answers each with `result`.
final class EventsAPIMock: @unchecked Sendable {
    private let lock = NSLock()
    private var _batches: [(events: [Event], baseURL: URL)] = []
    var batches: [(events: [Event], baseURL: URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _batches
    }
    var result: Result<Void, any Error> = .success(())
    var onSend: (@Sendable () -> Void)?

    func send(_ events: [Event], _ baseURL: URL, _ completion: @Sendable @escaping (Result<Void, any Error>) -> Void) {
        lock.lock()
        _batches.append((events, baseURL))
        lock.unlock()
        onSend?()
        completion(result)
    }
}

final class FlagsmithEventsTests: FlagsmithClientTestCase {
    let api = EventsAPIMock()

    func makeEvents(maxBuffer: Int = 1000) -> FlagsmithEvents {
        let events = FlagsmithEvents(maxBuffer: maxBuffer, retryDelay: 0) { [api] in api.send($0, $1, $2) }
        events.enabled = true
        return events
    }

    func flush(_ events: FlagsmithEvents) {
        let flushed = expectation(description: "Events flushed")
        events.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
    }

    func testTrackedEventIsSentWithItsIdentityValueAndMetadata() throws {
        // Given
        let events = makeEvents()

        // When
        events.trackEvent("checkout_completed", identifier: "user_123", value: .int(42),
                          traits: ["plan": .string("premium")], metadata: ["currency": .string("GBP")])
        flush(events)

        // Then
        let batch = try XCTUnwrap(api.batches.first)
        XCTAssertEqual(api.batches.count, 1)
        XCTAssertEqual(batch.baseURL.absoluteString, "https://events.api.flagsmith.com/")
        let event = try XCTUnwrap(batch.events.first)
        XCTAssertEqual(batch.events.count, 1)
        XCTAssertEqual(event.event, "checkout_completed")
        XCTAssertNil(event.featureName)
        XCTAssertEqual(event.identifier, "user_123")
        XCTAssertEqual(event.value, "42")
        XCTAssertEqual(event.traits, ["plan": .string("premium")])
        XCTAssertEqual(event.metadata, ["currency": .string("GBP"), "sdk_version": .string(Router.sdkVersion)])
    }

    func testEventsAreSentToTheConfiguredEventsAPI() throws {
        // Given
        let events = makeEvents()
        events.baseURL = try XCTUnwrap(URL(string: "http://events:8080/"))

        // When
        events.trackEvent("signed_up", identifier: nil, value: nil, traits: nil, metadata: nil)
        flush(events)

        // Then
        XCTAssertEqual(api.batches.map(\.baseURL.absoluteString), ["http://events:8080/"])
        XCTAssertEqual(api.batches.first?.events.first?.value, nil)
    }

    func testEventsTrackedWhileDisabledAreNotSent() {
        // Given
        let events = makeEvents()
        events.enabled = false

        // When
        events.trackEvent("checkout_completed", identifier: "user_123", value: nil, traits: nil, metadata: nil)
        events.trackExposureEvent(featureName: "banner", identifier: "user_123", value: nil, traits: nil, metadata: nil)
        flush(events)

        // Then
        XCTAssertTrue(api.batches.isEmpty)
    }

    func testExposureIsSentAsAFlagExposureEvent() throws {
        // Given
        let events = makeEvents()

        // When
        events.trackExposureEvent(featureName: "banner", identifier: "user_123", value: .string("control"),
                                  traits: nil, metadata: ["experiment_id": .int(1)])
        flush(events)

        // Then
        let event = try XCTUnwrap(api.batches.first?.events.first)
        XCTAssertEqual(event.event, "$flag_exposure")
        XCTAssertEqual(event.featureName, "banner")
        XCTAssertEqual(event.identifier, "user_123")
        XCTAssertEqual(event.value, "control")
        XCTAssertEqual(event.metadata, ["experiment_id": .int(1), "sdk_version": .string(Router.sdkVersion)])
    }

    func testRepeatedExposureIsSentOncePerBatch() {
        // Given
        let events = makeEvents()

        // When
        for experimentID in [1, 1, 2] {
            events.trackExposureEvent(featureName: "banner", identifier: "user_123", value: .string("control"),
                                      traits: nil, metadata: ["experiment_id": .int(experimentID)])
        }
        flush(events)
        events.trackExposureEvent(featureName: "banner", identifier: "user_123", value: .string("control"),
                                  traits: nil, metadata: ["experiment_id": .int(1)])
        flush(events)

        // Then
        XCTAssertEqual(api.batches.map { $0.events.map { $0.metadata["experiment_id"] } },
                       [[.int(1), .int(2)], [.int(1)]])
    }

    func testExperimentFlagExposesTheIdentityToTheVariantItWasServed() throws {
        // Given
        let events = makeEvents()
        let flag = try decoder.decode(Flag.self, from: Data("""
        {
            "feature": { "name": "banner" },
            "feature_state_value": "hello treatment",
            "enabled": true,
            "variant": "treatment",
            "metadata": { "experiment": { "id": 7, "name": "banner experiment", "in_experiment": true } }
        }
        """.utf8))

        // When
        events.trackExposure(to: flag, identifier: "user_123", traits: ["plan": .string("premium")])
        flush(events)

        // Then
        let event = try XCTUnwrap(api.batches.first?.events.first)
        XCTAssertEqual(event.event, "$flag_exposure")
        XCTAssertEqual(event.featureName, "banner")
        XCTAssertEqual(event.identifier, "user_123")
        XCTAssertEqual(event.value, "treatment")
        XCTAssertEqual(event.traits, ["plan": .string("premium")])
        XCTAssertEqual(event.metadata["experiment_id"], .int(7))
    }

    func testExperimentFlagDoesNotExposeAnIdentityOutsideARunningExperiment() throws {
        // Given
        let events = makeEvents()
        let flags = try decoder.decode([Flag].self, from: Data("""
        [
            { "feature": { "name": "no_experiment" }, "feature_state_value": "hello", "enabled": true },
            {
                "feature": { "name": "not_enrolled" }, "feature_state_value": "hello", "enabled": true,
                "metadata": { "experiment": { "id": 1, "name": "experiment", "in_experiment": false } }
            },
            {
                "feature": { "name": "disabled" }, "feature_state_value": "hello", "enabled": false, "variant": "treatment",
                "metadata": { "experiment": { "id": 2, "name": "experiment", "in_experiment": true } }
            },
            {
                "feature": { "name": "no_variant" }, "feature_state_value": "hello", "enabled": true,
                "metadata": { "experiment": { "id": 3, "name": "experiment", "in_experiment": true } }
            }
        ]
        """.utf8))

        // When
        for flag in flags {
            events.trackExposure(to: flag, identifier: "user_123", traits: nil)
        }
        flush(events)

        // Then
        XCTAssertTrue(api.batches.isEmpty)
    }

    func testEventsAreSentOnceTheBufferIsFull() {
        // Given
        let events = makeEvents(maxBuffer: 2)
        let sent = expectation(description: "Events sent")
        api.onSend = { sent.fulfill() }

        // When
        events.trackEvent("one", identifier: nil, value: nil, traits: nil, metadata: nil)
        events.trackEvent("two", identifier: nil, value: nil, traits: nil, metadata: nil)

        // Then
        wait(for: [sent], timeout: 5)
        XCTAssertEqual(api.batches.map { $0.events.map(\.event) }, [["one", "two"]])
    }

    func testEventsAreSentEveryFlushPeriod() {
        // Given
        let events = makeEvents()
        events.flushPeriod = 1
        let sent = expectation(description: "Events sent")
        api.onSend = { sent.fulfill() }

        // When
        events.trackEvent("checkout_completed", identifier: nil, value: nil, traits: nil, metadata: nil)

        // Then
        wait(for: [sent], timeout: 5)
        XCTAssertEqual(api.batches.map { $0.events.map(\.event) }, [["checkout_completed"]])
    }

    func testFailedEventsAreRetriedOnceThenDropped() {
        // Given
        let events = makeEvents()
        api.result = .failure(FlagsmithError.statusCode(503))

        // When
        events.trackEvent("checkout_completed", identifier: nil, value: nil, traits: nil, metadata: nil)
        flush(events)
        flush(events)

        // Then
        XCTAssertEqual(api.batches.map { $0.events.map(\.event) }, [["checkout_completed"], ["checkout_completed"]])
    }

    func testTrackingAnEventWithAReservedNameIsRejected() {
        // Given / When
        XCTAssertThrowsError(try Flagsmith.shared.trackEvent("$flag_exposure")) { error in
            // Then
            guard case FlagsmithError.invalidArgument = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
