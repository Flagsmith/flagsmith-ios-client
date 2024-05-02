//
//  FlagTests.swift
//  FlagsmithClientTests
//
//  Created by Richard Piazza on 3/16/22.
//

@testable import FlagsmithClient
import XCTest

final class FlagTests: FlagsmithClientTestCase {
    func testDecodeFlags() throws {
        let json = """
        [
            {
                "feature": {
                    "name": "app_theme",
                    "type": null,
                    "description": \"\"
                },
                "feature_state_value": 4,
                "enabled": true
            },
            {
                "feature": {
                    "name": "realtime_diagnostics_level"
                },
                "feature_state_value": "debug",
                "enabled": false
            }
        ]
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let flags = try decoder.decode([Flag].self, from: data)
        XCTAssertEqual(flags.count, 2)

        let enabledFlag = try XCTUnwrap(flags.first(where: { $0.enabled }))
        XCTAssertEqual(enabledFlag.feature.name, "app_theme")
        XCTAssertEqual(enabledFlag.value, .int(4))

        let disabledFlag = try XCTUnwrap(flags.first(where: { !$0.enabled }))
        XCTAssertEqual(disabledFlag.feature.name, "realtime_diagnostics_level")
        XCTAssertEqual(disabledFlag.value, .string("debug"))
    }
}
