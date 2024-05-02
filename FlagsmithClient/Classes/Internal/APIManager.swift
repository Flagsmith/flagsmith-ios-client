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
final class APIManager: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var _session: URLSession!
    private var session: URLSession {
        get {
            propertiesSerialAccessQueue.sync { _session }
        }
        set {
            propertiesSerialAccessQueue.sync(flags: .barrier) {
                _session = newValue
            }
        }
    }

    /// Base `URL` used for requests.
    private var _baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
    var baseURL: URL {
        get {
            propertiesSerialAccessQueue.sync { _baseURL }
        }
        set {
            propertiesSerialAccessQueue.sync {
                _baseURL = newValue
            }
        }
    }

    /// API Key unique to an organization.
    private var _apiKey: String?
    var apiKey: String? {
        get {
            propertiesSerialAccessQueue.sync { _apiKey }
        }
        set {
            propertiesSerialAccessQueue.sync {
                _apiKey = newValue
            }
        }
    }

    // store the completion handlers and accumulated data for each task
    private var tasksToCompletionHandlers: [Int: @Sendable (Result<Data, any Error>) -> Void] = [:]
    private var tasksToData: [Int: Data] = [:]
    private let serialAccessQueue = DispatchQueue(label: "flagsmithSerialAccessQueue", qos: .default)
    let propertiesSerialAccessQueue = DispatchQueue(label: "propertiesSerialAccessQueue", qos: .default)

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        serialAccessQueue.sync {
            if let dataTask = task as? URLSessionDataTask {
                if let completion = tasksToCompletionHandlers[dataTask.taskIdentifier] {
                    if let error = error {
                        DispatchQueue.main.async { completion(.failure(FlagsmithError.unhandled(error))) }
                    } else {
                        let data = tasksToData[dataTask.taskIdentifier] ?? Data()
                        DispatchQueue.main.async { completion(.success(data)) }
                    }
                }
                tasksToCompletionHandlers[dataTask.taskIdentifier] = nil
                tasksToData[dataTask.taskIdentifier] = nil
            }
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse,
                    completionHandler: @Sendable @escaping (CachedURLResponse?) -> Void)
    {
        serialAccessQueue.sync {
            // intercept and modify the cache settings for the response
            if Flagsmith.shared.cacheConfig.useCache {
                let newResponse = proposedResponse.response(withExpirationDuration: Int(Flagsmith.shared.cacheConfig.cacheTTL))
                DispatchQueue.main.async { completionHandler(newResponse) }
            } else {
                DispatchQueue.main.async { completionHandler(proposedResponse) }
            }
        }
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        serialAccessQueue.sync {
            var existingData = tasksToData[dataTask.taskIdentifier] ?? Data()
            existingData.append(data)
            tasksToData[dataTask.taskIdentifier] = existingData
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive _: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
        completionHandler(.allow)
    }

    /// Base request method that handles creating a `URLRequest` and processing
    /// the `URLSession` response.
    ///
    /// - parameters:
    ///   - router: The path and parameters that should be requested.
    ///   - completion: Function block executed with the result of the request.
    private func request(_ router: Router, completion: @Sendable @escaping (Result<Data, any Error>) -> Void) {
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
        serialAccessQueue.sync {
            let task = session.dataTask(with: request)
            tasksToCompletionHandlers[task.taskIdentifier] = completion
            task.resume()
        }
    }

    /// Requests a api route and only relays success or failure of the action.
    ///
    /// - parameters:
    ///   - router: The path and parameters that should be requested.
    ///   - completion: Function block executed with the result of the request.
    func request(_ router: Router, completion: @Sendable @escaping (Result<Void, any Error>) -> Void) {
        request(router) { (result: Result<Data, Error>) in
            switch result {
            case let .failure(error):
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
    func request<T: Decodable>(_ router: Router, using decoder: JSONDecoder = JSONDecoder(),
                               completion: @Sendable @escaping (Result<T, any Error>) -> Void)
    {
        request(router) { (result: Result<Data, Error>) in
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success(data):
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
