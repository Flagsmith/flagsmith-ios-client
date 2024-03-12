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
        
        apiManager.request(.getFlags) { (result: Result<Void, any Error>) in
            if case let .failure(e) = result {
                let error = e as? FlagsmithError
                let flagsmithError = try! XCTUnwrap(error)
                guard case .apiKey = flagsmithError else {
                    XCTFail("Wrong Error")
                    requestFinished.fulfill()
                    return
                }
            }
            
            requestFinished.fulfill()
        }
        
        wait(for: [requestFinished], timeout: 1.0)
    }
    
    /// Verify that an invalid API url produces the expected error.
    func testInvalidAPIURL() throws {
        apiManager.apiKey = "8D5ABC87-6BBF-4AE7-BC05-4DC1AFE770DF"
        apiManager.baseURL = URL(fileURLWithPath: "/dev/null")
        
        let requestFinished = expectation(description: "Request Finished")

        apiManager.request(.getFlags) { (result: Result<Void, any Error>) in
            if case let .failure(e) = result {
                let error = e as? FlagsmithError
                let flagsmithError: FlagsmithError? = try! XCTUnwrap(error)
                guard case .apiURL = flagsmithError else {
                    XCTFail("Wrong Error")
                    requestFinished.fulfill()
                    return
                }
            }
            
            requestFinished.fulfill()
        }
        
        wait(for: [requestFinished], timeout: 1.0)

    }

    @MainActor
    func testConcurrentRequests() throws {
        apiManager.apiKey = "8D5ABC87-6BBF-4AE7-BC05-4DC1AFE770DF"
        let concurrentQueue = DispatchQueue(label: "concurrentQueue", attributes: .concurrent)
        
        var expectations:[XCTestExpectation] = [];
        let iterations = 500
        
        for concurrentIteration in 1...iterations {
            let expectation = XCTestExpectation(description: "Multiple threads can access the APIManager \(concurrentIteration)")
            expectations.append(expectation)
            concurrentQueue.async {
                self.apiManager.request(.getFlags) { (result: Result<Void, any Error>) in
                  if case let .failure(e) = result {
                      let error = e as? FlagsmithError
                      // Ensure that we didn't have any errors during the process
                      XCTAssertTrue(error == nil)
                  }
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: expectations, timeout: 10)
      
        print("Finished!")
    }
}
