//
//  BackgroundEventsFlushTests.swift
//  FlagsmithClientTests
//

#if canImport(UIKit) && !os(watchOS)
    @testable import FlagsmithClient
    import UIKit
    import XCTest

    /// Records the background tasks begun and ended, and lets a test expire them.
    @MainActor
    final class BackgroundTasksMock: BackgroundTasks {
        private(set) var begun: [UIBackgroundTaskIdentifier] = []
        private(set) var ended: [UIBackgroundTaskIdentifier] = []
        private var expirations: [@MainActor () -> Void] = []
        var onEnd: (() -> Void)?

        func begin(expiration: @escaping @MainActor () -> Void) -> UIBackgroundTaskIdentifier {
            let task = UIBackgroundTaskIdentifier(rawValue: begun.count + 1)
            begun.append(task)
            expirations.append(expiration)
            return task
        }

        func end(_ task: UIBackgroundTaskIdentifier) {
            ended.append(task)
            onEnd?()
        }

        func expire() {
            expirations.forEach { $0() }
        }
    }

    @MainActor
    final class BackgroundEventsFlushTests: FlagsmithClientTestCase {
        let api = EventsAPIMock()
        let notificationCenter = NotificationCenter()
        let tasks = BackgroundTasksMock()

        func makeEvents() -> FlagsmithEvents {
            let events = FlagsmithEvents(requestTimeout: 60) { [api] in api.send($0, $1, $2) }
            events.enabled = true
            return events
        }

        func enterBackground() {
            notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        }

        func testEnteringTheBackgroundSendsTheBufferedEventsInsideABackgroundTask() {
            // Given
            let events = makeEvents()
            let flush = BackgroundEventsFlush(events: events, notificationCenter: notificationCenter) { [tasks] in tasks }
            events.trackEvent("checkout", identifier: "user_123", value: nil, traits: nil, metadata: nil)
            let ended = expectation(description: "Background task ended")
            tasks.onEnd = { ended.fulfill() }

            // When
            enterBackground()
            wait(for: [ended], timeout: 5)

            // Then
            XCTAssertEqual(api.batches.map { $0.events.map(\.event) }, [["checkout"]])
            XCTAssertEqual(tasks.begun, [UIBackgroundTaskIdentifier(rawValue: 1)])
            XCTAssertEqual(tasks.ended, tasks.begun)
            withExtendedLifetime(flush) {}
        }

        func testTheBackgroundTaskEndsWhenItRunsOutOfTime() {
            // Given
            let events = makeEvents()
            let flush = BackgroundEventsFlush(events: events, notificationCenter: notificationCenter) { [tasks] in tasks }
            api.responses = [nil]
            events.trackEvent("checkout", identifier: "user_123", value: nil, traits: nil, metadata: nil)

            // When
            enterBackground()
            tasks.expire()
            tasks.expire()

            // Then
            XCTAssertEqual(api.batches.count, 1)
            XCTAssertEqual(tasks.ended, [UIBackgroundTaskIdentifier(rawValue: 1)])
            withExtendedLifetime(flush) {}
        }

        func testEnteringTheBackgroundSendsNothingWhenTurnedOff() {
            // Given
            let events = makeEvents()
            events.flushOnBackground = false
            let flush = BackgroundEventsFlush(events: events, notificationCenter: notificationCenter) { [tasks] in tasks }
            events.trackEvent("checkout", identifier: "user_123", value: nil, traits: nil, metadata: nil)

            // When
            enterBackground()

            // Then
            XCTAssertTrue(api.batches.isEmpty)
            XCTAssertEqual(tasks.ended, tasks.begun)
            withExtendedLifetime(flush) {}
        }

        func testEnteringTheBackgroundIsIgnoredOnceTheClientIsGone() {
            // Given
            var events: FlagsmithEvents? = makeEvents()
            let flush = BackgroundEventsFlush(events: events!, notificationCenter: notificationCenter) { [tasks] in tasks }
            events = nil

            // When
            enterBackground()

            // Then
            XCTAssertTrue(tasks.begun.isEmpty)
            withExtendedLifetime(flush) {}
        }
    }
#endif
