@testable import FlagsmithClient
import XCTest

class SSEManagerTests: FlagsmithClientTestCase {
    var sseManager: SSEManager!

    override func setUp() {
        super.setUp()
        sseManager = SSEManager()
        sseManager.apiKey = "seemingly-valid-api-key"
    }

    override func tearDown() {
        sseManager = nil
        super.tearDown()
    }

    func testBaseURL() {
        let baseURL = URL(string: "https://my.url.com/")!
        sseManager.baseURL = baseURL
        XCTAssertEqual(sseManager.baseURL, baseURL)
    }

    func testAPIKey() {
        let apiKey = "testAPIKey"
        sseManager.apiKey = apiKey
        XCTAssertEqual(sseManager.apiKey, apiKey)
    }

    /// Verify that an invalid API key produces the expected error.
    func testInvalidAPIKey() throws {
        sseManager.apiKey = nil

        let requestFinished = expectation(description: "Request Finished")

        sseManager.start { result in
            if case let .failure(err) = result {
                let error = err as? FlagsmithError

                guard let flagsmithError = try? XCTUnwrap(error), case .apiKey = flagsmithError else {
                    XCTFail("Wrong Error")
                    requestFinished.fulfill()
                    return
                }
            }

            requestFinished.fulfill()
        }

        wait(for: [requestFinished], timeout: 1.0)
    }

    func testValidSSEData() {
        let requestFinished = expectation(description: "Request Finished")

        sseManager.start { result in
            if case let .failure(err) = result {
                XCTFail("Failed during testValidSSEData \(err)")
            }

            if case let .success(data) = result {
                XCTAssertNotNil(data)
                requestFinished.fulfill()
            }
        }

        sseManager.processSSEData("data: {\"updated_at\": 1689172003.899101}")

        wait(for: [requestFinished], timeout: 1.0)
    }

    func testInvalidSSEDataNotANum() {
        let requestFinished = expectation(description: "Request Finished")

        sseManager.start { result in
            if case let .failure(err) = result {
                let error = err as? FlagsmithError

                guard let flagsmithError = try? XCTUnwrap(error), case .decoding = flagsmithError else {
                    XCTFail("Wrong Error")
                    return
                }

                requestFinished.fulfill()
            }

            if case .success = result {
                XCTFail("Should not have succeeded")
            }
        }

        sseManager.processSSEData("data: {\"updated_at\": I-am-not-a-number-I-am-a-free-man}")

        wait(for: [requestFinished], timeout: 1.0)
    }

    func testIgnoresNonDataMessages() {
        let requestFinished = expectation(description: "Request Finished")

        sseManager.start { result in
            if case let .failure(err) = result {
                XCTFail("Failed during testValidSSEData \(err)")
            }

            if case let .success(data) = result {
                XCTAssertNotNil(data)
                requestFinished.fulfill()
            }
        }

        sseManager.processSSEData("If you've got to be told by someone then it's got to be me")
        sseManager.processSSEData("And that's not made from cheese and it doesn't get you free")
        sseManager.processSSEData("ping: 8374934498.3453445")
        sseManager.processSSEData("data: {\"updated_at\": 1689172003.899101}")

        wait(for: [requestFinished], timeout: 1.0)
    }

    func testFlagStreamYieldsOnlyOnDifferentFlags() {
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) else {
            XCTFail("AsyncStream is not available on this platform.")
            return
        }

        let flagsmith = Flagsmith.shared
        var continuation: AsyncStream<[Flag]>.Continuation?
        let stream = AsyncStream<[Flag]> { cont in
            continuation = cont
        }
        flagsmith.anyFlagStreamContinuation = continuation

        // Reset lastFlags to ensure a clean state for the test
        flagsmith.lastFlags = nil

        let flag1 = Flag(featureName: "test_feature_1", value: .string("value1"), enabled: true, featureType: "STANDARD")
        let flag2 = Flag(featureName: "test_feature_2", value: .int(123), enabled: false, featureType: "STANDARD")
        let flags1 = [flag1, flag2]

        let flag3 = Flag(featureName: "test_feature_3", value: .bool(true), enabled: true, featureType: "STANDARD")
        let flags2 = [flag1, flag3] // Different set of flags

        let firstYieldExpectation = expectation(description: "First flags yielded")
        let noYieldExpectation = expectation(description: "No yield on same flags")
        noYieldExpectation.isInverted = true
        let secondYieldExpectation = expectation(description: "Second flags yielded")

        // Use an actor to make the counter thread-safe for Swift 5 compatibility
        actor YieldCounter {
            private var count = 0

            func increment() -> Int {
                count += 1
                return count
            }
        }

        let yieldCounter = YieldCounter()
        let taskCompletionExpectation = expectation(description: "Task completed")

        let _ = Task {
            for await flags in stream {
                let currentCount = await yieldCounter.increment()
                switch currentCount {
                case 1:
                    XCTAssertEqual(flags, flags1)
                    firstYieldExpectation.fulfill()
                case 2:
                    XCTAssertEqual(flags, flags2)
                    secondYieldExpectation.fulfill()
                default:
                    XCTFail("Unexpected yield from stream")
                }
            }
            // Signal that the task has finished processing all stream items
            taskCompletionExpectation.fulfill()
        }

        // 1. Call with new flags (should yield)
        flagsmith.updateFlagStreamAndLastUpdatedAt(flags1)
        wait(for: [firstYieldExpectation], timeout: 1.0)

        // 2. Call with same flags (should NOT yield)
        flagsmith.updateFlagStreamAndLastUpdatedAt(flags1)
        wait(for: [noYieldExpectation], timeout: 0.1) // Short timeout to ensure no yield

        // 3. Call with different flags (should yield)
        flagsmith.updateFlagStreamAndLastUpdatedAt(flags2)
        wait(for: [secondYieldExpectation], timeout: 1.0)

        // Clean up: stop the stream and wait for task to complete
        continuation?.finish()

        // Wait for the async task to finish processing all items before continuing
        wait(for: [taskCompletionExpectation], timeout: 1.0)

        // Reset Flagsmith state to avoid interference with other tests
        flagsmith.anyFlagStreamContinuation = nil
        flagsmith.lastFlags = nil
    }
}
