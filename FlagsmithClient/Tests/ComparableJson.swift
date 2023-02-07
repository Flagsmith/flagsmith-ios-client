//
//  ComparableJson.swift
//  FlagsmithClientTests
//
//  Created by Rob Valdes on 07/02/23.
//

import XCTest

extension String {
    func json(using encoding: String.Encoding) throws -> NSDictionary {
        return try self.data(using: encoding).json()
    }
}

extension Optional where Wrapped == Data {
    func json() throws -> NSDictionary {
        let data = try XCTUnwrap(self)
        return try data.json()
    }
}

extension Data {
    func json() throws -> NSDictionary {
        let json = try JSONSerialization.jsonObject(with: self)
        let dict = json as! [String : Any]
        return NSDictionary(dictionary: dict)
    }
}
