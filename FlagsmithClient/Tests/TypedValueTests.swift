//
//  TypedValueTests.swift
//  FlagsmithClient
//
//  Created by Richard Piazza on 3/16/22.
//

@testable import FlagsmithClient
import XCTest

/// Tests `TypedValue`
final class TypedValueTests: FlagsmithClientTestCase {
    func testDecodeBool() throws {
        let json = "true"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let typedValue = try decoder.decode(TypedValue.self, from: data)
        XCTAssertEqual(typedValue, .bool(true))
    }

    func testDecodeFloat() throws {
        let json = "3.14"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let typedValue = try decoder.decode(TypedValue.self, from: data)
        XCTAssertEqual(typedValue, .float(3.14))
    }

    func testDecodeInt() throws {
        let json = "47"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let typedValue = try decoder.decode(TypedValue.self, from: data)
        XCTAssertEqual(typedValue, .int(47))
    }

    func testDecodeString() throws {
        let json = "\"DarkMode\""
        let data = try XCTUnwrap(json.data(using: .utf8))
        let typedValue = try decoder.decode(TypedValue.self, from: data)
        XCTAssertEqual(typedValue, .string("DarkMode"))
    }

    func testDecodeNull() throws {
        let json = "null"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let typedValue = try decoder.decode(TypedValue.self, from: data)
        XCTAssertEqual(typedValue, .null)
    }

    func testEncodeBool() throws {
        let typedValue: TypedValue = .bool(false)
        let data = try encoder.encode(typedValue)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(json, "false")
    }

    func testEncodeFloat() throws {
        let typedValue: TypedValue = .float(1.888)
        let data = try encoder.encode(typedValue)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.hasPrefix("1.888"))
    }

    func testEncodeInt() throws {
        let typedValue: TypedValue = .int(88)
        let data = try encoder.encode(typedValue)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(json, "88")
    }

    func testEncodeString() throws {
        let typedValue: TypedValue = .string("iOS 15.4")
        let data = try encoder.encode(typedValue)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(json, "\"iOS 15.4\"")
    }
}
