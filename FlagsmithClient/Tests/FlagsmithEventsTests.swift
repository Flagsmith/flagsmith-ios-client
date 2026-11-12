//
//  FlagsmithEventsTests.swift
//  FlagsmithClientTests
//

@testable import FlagsmithClient
import XCTest

/// Records the batches sent to the events API, and answers each with the next of `responses`, then with a 202.
/// A `nil` response leaves the request unanswered until it is cancelled.
final class EventsAPIMock: @unchecked Sendable {
    private let lock = NSLock()
    private var _batches: [(events: [Event], baseURL: URL)] = []
    var batches: [(events: [Event], baseURL: URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _batches
    }

    private var _cancelled = 0
    /// How many requests were cancelled.
    var cancelled: Int {
        lock.lock()
        defer { lock.unlock() }
        return _cancelled
    }

    var responses: [Result<Int, any Error>?] = []
    var onSend: (@Sendable () -> Void)?

    func send(_ events: [Event], _ baseURL: URL,
              _ completion: @Sendable @escaping (Result<Int, any Error>) -> Void) -> @Sendable () -> Void
    {
        lock.lock()
        _batches.append((events, baseURL))
        let response = responses.isEmpty ? .success(202) : responses.removeFirst()
        lock.unlock()
        onSend?()
        guard let response = response else {
            return { [self] in
                lock.lock()
                _cancelled += 1
                lock.unlock()
                completion(.failure(FlagsmithError.unhandled(URLError(.cancelled))))
            }
        }
        completion(response)
        return {}
    }
}

final class FlagsmithEventsTests: FlagsmithClientTestCase {
    let api = EventsAPIMock()

    func makeEvents(maxBuffer: Int = 1000, requestTimeout: TimeInterval = 3,
                    jitter: @escaping @Sendable (TimeInterval) -> TimeInterval = { _ in 0 }) -> FlagsmithEvents
    {
        let events = FlagsmithEvents(maxBuffer: maxBuffer, requestTimeout: requestTimeout, jitter: jitter) { [api] in
            api.send($0, $1, $2)
        }
        events.enabled = true
        return events
    }

    func flush(_ events: FlagsmithEvents) {
        let flushed = expectation(description: "Events flushed")
        events.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
    }

    func track(_ events: FlagsmithEvents, _ names: String...) {
        for name in names {
            events.trackEvent(name, identifier: "user_123", value: nil, traits: nil, metadata: nil)
        }
    }

    /// The events of each batch sent, by name.
    var sentEvents: [[String]] {
        api.batches.map { $0.events.map(\.event) }
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

    func testABatchIsRetriedUntilTheEventsAPIAcceptsIt() {
        // Given
        let events = makeEvents()
        api.responses = [.success(503), .failure(FlagsmithError.unhandled(URLError(.networkConnectionLost)))]

        // When
        track(events, "checkout")
        flush(events)

        // Then
        XCTAssertEqual(sentEvents, [["checkout"], ["checkout"], ["checkout"]])
    }

    func testRetriesBackOffFromTheRetryDelayDoublingWithJitter() {
        // Given
        let delays = DelaysRecorder()
        let events = makeEvents { delays.record($0) }
        api.responses = [.success(503), .success(503), .success(503)]

        // When
        track(events, "checkout")
        flush(events)

        // Then
        XCTAssertEqual(delays.delays, [1, 2])
    }

    func testEachStatusIsRetriedOrNot() {
        for status in [408, 429, 500, 502, 503, 504] {
            XCTAssertEqual(FlagsmithEvents.Outcome(.success(status)), .retryable(keep: status != 500), "\(status)")
        }
        for status in [200, 202] {
            XCTAssertEqual(FlagsmithEvents.Outcome(.success(status)), .delivered, "\(status)")
        }
        for status in [400, 404, 413, 501] {
            XCTAssertEqual(FlagsmithEvents.Outcome(.success(status)), .rejected, "\(status)")
        }
        for status in [401, 403] {
            XCTAssertEqual(FlagsmithEvents.Outcome(.success(status)), .unauthorised, "\(status)")
        }
        XCTAssertEqual(FlagsmithEvents.Outcome(.failure(FlagsmithError.unhandled(URLError(.timedOut)))),
                       .retryable(keep: true))
        XCTAssertEqual(FlagsmithEvents.Outcome(.failure(FlagsmithError.apiKey)), .rejected)
    }

    func testARequestThatIsNotAnsweredTimesOutAndIsRetried() {
        // Given
        let events = makeEvents(requestTimeout: 0.2)
        api.responses = [nil]

        // When
        track(events, "checkout")
        flush(events)

        // Then
        XCTAssertEqual(sentEvents, [["checkout"], ["checkout"]])
        XCTAssertEqual(api.cancelled, 1)
    }

    func testABatchThatKeepsFailingIsSentWithTheNextFlushAheadOfNewerEvents() {
        // Given
        let events = makeEvents()
        api.responses = [.success(503), .success(503), .success(503)]

        // When
        track(events, "add_to_cart")
        flush(events)
        track(events, "checkout")
        flush(events)

        // Then
        XCTAssertEqual(sentEvents, [["add_to_cart"], ["add_to_cart"], ["add_to_cart"], ["add_to_cart", "checkout"]])
    }

    func testABatchWhoseLastAttemptGetsAServerErrorIsDropped() {
        // Given
        let events = makeEvents()
        api.responses = [.success(503), .success(503), .success(500)]

        // When
        track(events, "add_to_cart")
        flush(events)
        track(events, "checkout")
        flush(events)

        // Then
        XCTAssertEqual(sentEvents, [["add_to_cart"], ["add_to_cart"], ["add_to_cart"], ["checkout"]])
    }

    func testABatchTheEventsAPIRejectsIsDroppedAtOnce() {
        // Given
        let events = makeEvents()
        api.responses = [.success(400)]

        // When
        track(events, "add_to_cart")
        flush(events)
        track(events, "checkout")
        flush(events)

        // Then
        XCTAssertEqual(sentEvents, [["add_to_cart"], ["checkout"]])
    }

    func testAFullBufferDropsItsOldestEvent() {
        // Given
        let events = makeEvents(maxBuffer: 3)
        api.responses = [.success(503), .success(503), .success(503)]

        // When
        track(events, "one", "two", "three")
        flush(events)
        track(events, "four")
        flush(events)

        // Then
        XCTAssertEqual(sentEvents.last, ["two", "three", "four"])
        XCTAssertEqual(sentEvents.count, 4)
    }

    func testAnEventsAPIRefusingTheEnvironmentKeyStopsEventTrackingUntilTheKeyChanges() {
        for status in [401, 403] {
            // Given
            let api = EventsAPIMock()
            api.responses = [.success(status)]
            let events = FlagsmithEvents { api.send($0, $1, $2) }
            events.enabled = true

            // When
            events.trackEvent("add_to_cart", identifier: nil, value: nil, traits: nil, metadata: nil)
            flush(events)
            events.trackEvent("checkout", identifier: nil, value: nil, traits: nil, metadata: nil)
            flush(events)
            events.environmentKeyChanged()
            events.trackEvent("signed_up", identifier: nil, value: nil, traits: nil, metadata: nil)
            flush(events)

            // Then
            XCTAssertEqual(api.batches.map { $0.events.map(\.event) }, [["add_to_cart"], ["signed_up"]], "\(status)")
        }
    }

    func testClosingSendsTheBufferedEventsRetriesIncludedThenStopsSendingEvents() {
        // Given
        let events = makeEvents()
        api.responses = [.success(503)]
        track(events, "checkout")

        // When
        let closed = expectation(description: "Closed")
        events.close(timeout: 5) { closed.fulfill() }
        wait(for: [closed], timeout: 5)
        track(events, "signed_up")
        flush(events)

        // Then
        XCTAssertEqual(sentEvents, [["checkout"], ["checkout"]])
        XCTAssertFalse(events.enabled)
    }

    func testClosingReturnsWithinItsTimeoutWhenTheEventsAPIDoesNotAnswer() {
        // Given
        let events = makeEvents(requestTimeout: 60)
        api.responses = [nil]
        track(events, "checkout")

        // When
        let closed = expectation(description: "Closed")
        let started = Date()
        events.close(timeout: 0.2) { closed.fulfill() }
        wait(for: [closed], timeout: 5)

        // Then
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        XCTAssertEqual(api.cancelled, 1)
        XCTAssertEqual(sentEvents, [["checkout"]])
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

/// Records the backoffs before jitter, and waits none of them.
final class DelaysRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _delays: [TimeInterval] = []
    var delays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return _delays
    }

    func record(_ delay: TimeInterval) -> TimeInterval {
        lock.lock()
        _delays.append(delay)
        lock.unlock()
        return 0
    }
}
