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

    func testDecodeReason() throws {
        let json = """
        [
            {"feature": {"name": "experiment"}, "feature_state_value": "variant", "enabled": true, "reason": "SPLIT; weight=30"},
            {"feature": {"name": "no_reason"}, "feature_state_value": "value", "enabled": true}
        ]
        """

        let flags = try decoder.decode([Flag].self, from: Data(json.utf8))

        XCTAssertEqual(flags[0].reason, "SPLIT; weight=30")
        XCTAssertNil(flags[1].reason)
    }

    func testDecodeReasonFromIdentity() throws {
        let json = """
        {
            "flags": [
                {"feature": {"name": "font_size"}, "feature_state_value": 24, "enabled": true, "reason": "TARGETING_MATCH"}
            ],
            "traits": []
        }
        """

        let identity = try decoder.decode(Identity.self, from: Data(json.utf8))

        XCTAssertEqual(identity.flags.first?.reason, "TARGETING_MATCH")
    }

    func testEncodeDecodeReasonRoundTrip() throws {
        let flag = Flag(featureName: "font_size", value: .int(16), enabled: true, reason: "DEFAULT")

        let data = try encoder.encode([flag])
        let decoded = try decoder.decode([Flag].self, from: data)

        XCTAssertEqual(decoded, [flag])
        XCTAssertEqual(decoded.first?.reason, "DEFAULT")
    }
}
