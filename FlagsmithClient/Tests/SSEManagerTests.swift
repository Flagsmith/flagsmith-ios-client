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
    
    func testInalidSSEDataNotANum() {
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
            
            if case .success(_) = result {
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
}
