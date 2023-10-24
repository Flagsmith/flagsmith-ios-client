//
//  APIManager.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Handles interaction with a **Flagsmith** api.
final class APIManager : NSObject, URLSessionDataDelegate {

  private var session: URLSession!
  private let lock: NSLock = NSLock()
  private let delegateQueue: OperationQueue = OperationQueue()
  
  /// Base `URL` used for requests.
  var baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
  /// API Key unique to an organization.
  var apiKey: String?
    
  // store the completion handlers and accumulated data for each task
  private var tasksToCompletionHandlers:[URLSessionDataTask:(Result<Data, Error>) -> Void] = [:]
  private var tasksToData:[URLSessionDataTask:Data] = [:]
  
  override init() {
    super.init()
    let configuration = URLSessionConfiguration.default
    delegateQueue.maxConcurrentOperationCount = 1
    self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let dataTask = task as? URLSessionDataTask {
      lock.lock()
      defer { lock.unlock() }
      if let completion = tasksToCompletionHandlers[dataTask] {
        if let error = error {
          completion(.failure(FlagsmithError.unhandled(error)))
        }
        else {
          let data = tasksToData[dataTask] ?? Data()
          completion(.success(data as Data))
        }
      }
      tasksToCompletionHandlers[dataTask] = nil
      tasksToData[dataTask] = nil
    }
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
    // intercept and modify the cache settings for the response
    if Flagsmith.shared.cacheConfig.useCache {
      let newResponse = proposedResponse.response(withExpirationDuration: Int(Flagsmith.shared.cacheConfig.cacheTTL))
      completionHandler(newResponse)
    } else {
      completionHandler(proposedResponse)
    }
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    lock.lock()
    defer { lock.unlock() }

    var existingData = tasksToData[dataTask] ?? Data()
    existingData.append(data)
    tasksToData[dataTask] = existingData
  }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
    }
  
  /// Base request method that handles creating a `URLRequest` and processing
  /// the `URLSession` response.
  ///
  /// - parameters:
  ///   - router: The path and parameters that should be requested.
  ///   - completion: Function block executed with the result of the request.
  private func request(_ router: Router, completion: @escaping (Result<Data, Error>) -> Void) {
    guard let apiKey = apiKey, !apiKey.isEmpty else {
      completion(.failure(FlagsmithError.apiKey))
      return
    }
    
    var request: URLRequest
    do {
      request = try router.request(baseUrl: baseURL, apiKey: apiKey)
    } catch {
      completion(.failure(error))
      return
    }
    
    // set the cache policy based on Flagsmith settings
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    session.configuration.urlCache = Flagsmith.shared.cacheConfig.cache
    if Flagsmith.shared.cacheConfig.useCache {
      request.cachePolicy = .useProtocolCachePolicy
      if Flagsmith.shared.cacheConfig.skipAPI {
        request.cachePolicy = .returnCacheDataElseLoad
      }
    }
    
    // we must use the delegate form here, not the completion handler, to be able to modify the cache
    lock.lock()
    let task = session.dataTask(with: request)
    tasksToCompletionHandlers[task] = completion
    lock.unlock()
    task.resume()
  }
  
  /// Requests a api route and only relays success or failure of the action.
  ///
  /// - parameters:
  ///   - router: The path and parameters that should be requested.
  ///   - completion: Function block executed with the result of the request.
  func request(_ router: Router, completion: @escaping (Result<Void, Error>) -> Void) {
    request(router) { (result: Result<Data, Error>) in
      switch result {
      case .failure(let error):
        completion(.failure(FlagsmithError(error)))
      case .success:
        completion(.success(()))
      }
    }
  }
  
  /// Requests a api route and attempts the decode the response.
  ///
  /// - parameters:
  ///   - router: The path and parameters that should be requested.
  ///   - decoder: `JSONDecoder` used to deserialize the response data.
  ///   - completion: Function block executed with the result of the request.
  func request<T: Decodable>(_ router: Router, using decoder: JSONDecoder = JSONDecoder(), completion: @escaping (Result<T, Error>) -> Void) {
    request(router) { (result: Result<Data, Error>) in
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success(let data):
        do {
          let value = try decoder.decode(T.self, from: data)
          completion(.success(value))
        } catch {
          completion(.failure(FlagsmithError(error)))
        }
      }
    }
  }
}
