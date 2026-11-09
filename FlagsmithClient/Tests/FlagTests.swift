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

    func testDecodeFlagServedInExperiment() throws {
        // Given
        let json = """
        {
            "feature": { "name": "banner" },
            "feature_state_value": "hello treatment",
            "enabled": true,
            "variant": "treatment",
            "metadata": { "experiment": { "id": 1, "name": "banner experiment", "in_experiment": true } }
        }
        """

        // When
        let flag = try decoder.decode(Flag.self, from: Data(json.utf8))

        // Then
        XCTAssertEqual(flag.value, .string("hello treatment"))
        XCTAssertEqual(flag.variant, "treatment")
        XCTAssertEqual(flag.experiment, Experiment(id: 1, name: "banner experiment", inExperiment: true))
        XCTAssertEqual(try decoder.decode(Flag.self, from: encoder.encode(flag)).experiment, flag.experiment)
    }

    func testDecodeFlagWithoutExperiment() throws {
        // Given
        let json = """
        [
            { "feature": { "name": "banner" }, "feature_state_value": "hello", "enabled": true },
            { "feature": { "name": "theme" }, "feature_state_value": "dark", "enabled": true, "metadata": { "experiment": "unknown" } }
        ]
        """

        // When
        let flags = try decoder.decode([Flag].self, from: Data(json.utf8))

        // Then
        XCTAssertEqual(flags.map(\.variant), [nil, nil])
        XCTAssertEqual(flags.map(\.experiment), [nil, nil])
    }

    func testFlagChangesWhenTheIdentityIsEnrolledInAnExperimentServingTheSameValue() throws {
        // Given
        let json = """
        [
            { "feature": { "name": "banner" }, "feature_state_value": "hello", "enabled": true },
            {
                "feature": { "name": "banner" },
                "feature_state_value": "hello",
                "enabled": true,
                "variant": "control",
                "metadata": { "experiment": { "id": 1, "name": "banner experiment", "in_experiment": false } }
            },
            {
                "feature": { "name": "banner" },
                "feature_state_value": "hello",
                "enabled": true,
                "variant": "control",
                "metadata": { "experiment": { "id": 1, "name": "banner experiment", "in_experiment": true } }
            }
        ]
        """

        // When
        let flags = try decoder.decode([Flag].self, from: Data(json.utf8))

        // Then
        XCTAssertNotEqual(flags[0], flags[1])
        XCTAssertNotEqual(flags[1], flags[2])
        XCTAssertEqual(flags[2], try decoder.decode(Flag.self, from: encoder.encode(flags[2])))
    }
}
