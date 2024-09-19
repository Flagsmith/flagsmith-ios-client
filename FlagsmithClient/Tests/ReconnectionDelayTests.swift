@testable import FlagsmithClient
import XCTest

class ReconnectionDelayTests: XCTestCase {
    func testInitialDelay() {
        let reconnectionDelay = ReconnectionDelay(initialDelay: 1.0, maxDelay: 16.0, multiplier: 2.0)
        XCTAssertEqual(reconnectionDelay.nextDelay(), 1.0, "Initial delay should be 1.0 seconds")
    }

    func testExponentialBackoff() {
        let reconnectionDelay = ReconnectionDelay(initialDelay: 1.0, maxDelay: 16.0, multiplier: 2.0)
        XCTAssertEqual(reconnectionDelay.nextDelay(), 1.0, "First delay should be 1.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 2.0, "Second delay should be 2.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 4.0, "Third delay should be 4.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 8.0, "Fourth delay should be 8.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 16.0, "Fifth delay should be 16.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 16.0, "Subsequent delays should be capped at 16.0 seconds")
    }

    func testMaxDelay() {
        let reconnectionDelay = ReconnectionDelay(initialDelay: 1.0, maxDelay: 5.0, multiplier: 2.0)
        XCTAssertEqual(reconnectionDelay.nextDelay(), 1.0, "First delay should be 1.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 2.0, "Second delay should be 2.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 4.0, "Third delay should be 4.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 5.0, "Fourth delay should be capped at 5.0 seconds")
        XCTAssertEqual(reconnectionDelay.nextDelay(), 5.0, "Subsequent delays should be capped at 5.0 seconds")
    }

    func testReset() {
        let reconnectionDelay = ReconnectionDelay(initialDelay: 1.0, maxDelay: 16.0, multiplier: 2.0)
        _ = reconnectionDelay.nextDelay() // 1.0
        _ = reconnectionDelay.nextDelay() // 2.0
        _ = reconnectionDelay.nextDelay() // 4.0
        reconnectionDelay.reset()
        XCTAssertEqual(reconnectionDelay.nextDelay(), 1.0, "After reset, delay should be 1.0 seconds")
    }
}
