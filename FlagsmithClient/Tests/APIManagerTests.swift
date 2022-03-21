//
//  APIManagerTests.swift
//  FlagsmithClientTests
//
//  Created by Richard Piazza on 3/18/22.
//

import XCTest
@testable import FlagsmithClient

final class APIManagerTests: FlagsmithClientTestCase {
    
    let apiManager = APIManager()
    
    /// Verify that an invalid API key produces the expected error.
    func testInvalidAPIKey() throws {
        apiManager.apiKey = nil
        
        let requestFinished = expectation(description: "Request Finished")
        var error: FlagsmithError?
        
        apiManager.request(.getFlags) { (result: Result<Void, Error>) in
            if case let .failure(e) = result {
                error = e as? FlagsmithError
            }
            
            requestFinished.fulfill()
        }
        
        wait(for: [requestFinished], timeout: 1.0)
        
        let flagsmithError = try XCTUnwrap(error)
        guard case .apiKey = flagsmithError else {
            XCTFail("Wrong Error")
            return
        }
    }
    
    /// Verify that an invalid API url produces the expected error.
    func testInvalidAPIURL() throws {
        apiManager.apiKey = "8D5ABC87-6BBF-4AE7-BC05-4DC1AFE770DF"
        apiManager.baseURL = URL(fileURLWithPath: "/dev/null")
        
        let requestFinished = expectation(description: "Request Finished")
        var error: FlagsmithError?
        
        apiManager.request(.getFlags) { (result: Result<Void, Error>) in
            if case let .failure(e) = result {
                error = e as? FlagsmithError
            }
            
            requestFinished.fulfill()
        }
        
        wait(for: [requestFinished], timeout: 1.0)
        
        let flagsmithError = try XCTUnwrap(error)
        guard case .apiURL = flagsmithError else {
            XCTFail("Wrong Error")
            return
        }
    }
}
