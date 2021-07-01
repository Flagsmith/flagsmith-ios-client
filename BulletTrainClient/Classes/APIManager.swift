//
//  APIManager.swift
//  BulletTrainClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

enum Router {
  private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
  }
  
  case getFlags
  case getIdentity(identity: String)
  case postTrait(trait: Trait, identity: String)
  
  private var method: HTTPMethod {
    switch self {
    case .getFlags, .getIdentity:
      return .get
    case .postTrait:
      return .post
    }
  }
  
  private var path: String {
    switch self {
    case .getFlags:
      return "flags/"
    case .getIdentity(let identity):
      return "identities/?identifier=\(identity)"
    case .postTrait(let _, let _):
      return "traits/"
    }
  }
  
  private var body: Result<Data?, Error> {
    switch self {
    case .getFlags, .getIdentity:
      return .success(nil)
    case .postTrait(let trait, let identifier):
      do {
        let postTraitStruct = PostTrait(key:trait.key, value:trait.value, identifier:identifier)
        let json = try JSONEncoder().encode(postTraitStruct)
        return .success(json)
      } catch {
        return .failure(error)
      }
    }
  }
  
  func request(baseUrl: URL, apiKey: String) throws -> URLRequest {
    var request = URLRequest(url: baseUrl.appendingPathComponent(path))
    request.httpMethod = method.rawValue
    
    switch body {
    case .success(let body):
      request.httpBody = body
    case .failure(let error):
      throw error
    }
    
    request.addValue(apiKey, forHTTPHeaderField: "X-Environment-Key")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    return request
  }
}

class APIManager {
  enum NetworkError: Error {
    case noResponseBody
    case defaultError
    
    var localizedDescription: String {
      switch self {
      case .noResponseBody:
        return NSLocalizedString("Response has no message body", comment: "No response body network error")
      case .defaultError:
        return NSLocalizedString("Some error occurred", comment: "Default network error")
      }
    }
  }
  
  private let session: URLSession
  
  var baseURL = URL(string: "https://api.bullet-train.io/api/v1/")!
  var apiKey: String?
  
  init() {
    let configuration = URLSessionConfiguration.default
    self.session = URLSession(configuration: configuration)
  }
  
  func request<T: Decodable>(_ router: Router, completion: @escaping (Result<T, Error>) -> Void) {
    guard let apiKey = apiKey else {
      fatalError("API Key is missing")
    }
    
    do {
      let task = try session.dataTask(with: router.request(baseUrl: baseURL, apiKey: apiKey)) { (data, response, error) -> Void in
        if let error = error {
          print("URL Session Task Failed: %@", error.localizedDescription)
          completion(.failure(error))
          return
        }
        
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(statusCode) else {
          let error = NetworkError.defaultError
          print("HTTP Request Failed: %@", error.localizedDescription)
          completion(.failure(error))
          return
        }
        
        guard let data = data else {
          let error = NetworkError.noResponseBody
          print("HTTP Request Failed: %@", error.localizedDescription)
          completion(.failure(error))
          return
        }
        
        do {
          let result = try JSONDecoder().decode(T.self, from: data)
          completion(.success(result))
        } catch {
          print("JSON Decoding Failed: %@", error.localizedDescription)
          completion(.failure(error))
        }
      }
      task.resume()
    } catch {
      print("Building HTTP Request Failed: %@", error.localizedDescription)
      completion(.failure(error))
    }
  }
  
}
