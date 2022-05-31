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
class APIManager {
  
  private let session: URLSession
  
  /// Base `URL` used for requests.
  var baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
  /// API Key unique to an organization.
  var apiKey: String?
  
  init() {
    let configuration = URLSessionConfiguration.default
    self.session = URLSession(configuration: configuration)
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
    
    let request: URLRequest
    do {
      request = try router.request(baseUrl: baseURL, apiKey: apiKey)
    } catch {
      completion(.failure(error))
      return
    }
    
    session.dataTask(with: request) { data, response, error in
      guard error == nil else {
        completion(.failure(FlagsmithError.unhandled(error!)))
        return
      }
      
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard (200...299).contains(statusCode) else {
        completion(.failure(FlagsmithError.statusCode(statusCode)))
        return
      }
      
      // The documentation indicates the data should be provided
      // since error was found to be nil at this point. Either way
      // the 'Decodable' variation will handle any invalid `Data`.
      completion(.success(data ?? Data()))
    }.resume()
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
