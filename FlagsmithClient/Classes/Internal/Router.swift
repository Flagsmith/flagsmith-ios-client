//
//  Router.swift
//  FlagsmithClient
//
//  Created by Richard Piazza on 3/18/22.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum Router {
  private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
  }
  
  case getFlags
  case getIdentity(identity: String)
  case postTrait(trait: Trait, identity: String)
  case postAnalytics(events: [String:Int])
  
  private var method: HTTPMethod {
    switch self {
    case .getFlags, .getIdentity:
      return .get
    case .postTrait, .postAnalytics:
      return .post
    }
  }
  
  private var path: String {
    switch self {
    case .getFlags:
      return "flags/"
    case .getIdentity:
      return "identities/"
    case .postTrait:
      return "traits/"
    case .postAnalytics:
      return "analytics/flags/"
    }
  }

  private var parameters: [URLQueryItem]? {
    switch self {
    case .getIdentity(let identity):
      return [URLQueryItem(name: "identifier", value: identity)]
    default:
      return nil
    }
  }

  private func body(using encoder: JSONEncoder) throws -> Data? {
    switch self {
    case .getFlags, .getIdentity:
      return nil
    case .postTrait(let trait, let identifier):
      let traitWithIdentity = Trait(trait: trait, identifier: identifier)
      return try encoder.encode(traitWithIdentity)
    case .postAnalytics(let events):
      return try encoder.encode(events)
    }
  }
  
  /// Generate a `URLRequest` with headers and encoded body.
  ///
  /// - parameters:
  ///  - baseUrl: The base URL of the api on which to base the request.
  ///  - apiKey: The organization key to provide in the request headers.
  ///  - encoder: `JSONEncoder` used to encode the request body.
  func request(baseUrl: URL,
               apiKey: String,
               using encoder: JSONEncoder = JSONEncoder()
  ) throws -> URLRequest {
    let urlString = baseUrl.appendingPathComponent(path).absoluteString
    var urlComponents = URLComponents(string: urlString)
    urlComponents?.queryItems = parameters
    guard let url = urlComponents?.url else {
      // This is unlikely to ever be hit, but it is safer than
      // relying on the forcefully-unwrapped optional.
      throw FlagsmithError.apiURL(urlString)
    }
    
    guard !url.isFileURL else {
      throw FlagsmithError.apiURL(urlString)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    if let body = try self.body(using: encoder) {
      request.httpBody = body
    }
    request.addValue(apiKey, forHTTPHeaderField: "X-Environment-Key")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    return request
  }
}
