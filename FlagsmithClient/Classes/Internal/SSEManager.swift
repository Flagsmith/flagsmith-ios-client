//
//  SSEManager.swift
//  FlagsmithClient
//
//  Created by Gareth Reese on 13/09/2024.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// SSEManager handles interaction with the Flagsmith SSE real-time API.
/// It manages the connection to the SSE endpoint, processes incoming events,
/// and handles reconnection logic with a backoff strategy.
final class SSEManager: NSObject, URLSessionDataDelegate, @unchecked Sendable {
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
    
    private var _dataTask: URLSessionDataTask?
    private var dataTask: URLSessionDataTask? {
        get {
            propertiesSerialAccessQueue.sync { _dataTask }
        }
        set {
            propertiesSerialAccessQueue.sync(flags: .barrier) {
                _dataTask = newValue
            }
        }
    }
    
    /// Base `URL` used for requests.
    private var _baseURL = URL(string: "https://realtime.flagsmith.com/")!
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
    
    var isStarted: Bool {
        return completionHandler != nil
    }
    
    private var completionHandler: CompletionHandler<FlagEvent>?
    private let serialAccessQueue = DispatchQueue(label: "sseFlagsmithSerialAccessQueue", qos: .default)
    let propertiesSerialAccessQueue = DispatchQueue(label: "ssePropertiesSerialAccessQueue", qos: .default)
    private let reconnectionDelay = ReconnectionDelay()
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    // Helper function to process SSE data
    internal func processSSEData(_ data: String) {
        // Split the data into lines and decode the 'data:' lines from JSON into FlagEvent objects
        let lines = data.components(separatedBy: "\n")
        for line in lines where line.hasPrefix("data:") {
            let json = line.replacingOccurrences(of: "data:", with: "")
            if let jsonData = json.data(using: .utf8) {
                do {
                    let flagEvent = try JSONDecoder().decode(FlagEvent.self, from: jsonData)
                    completionHandler?(.success(flagEvent))
                } catch {
                    if let error = error as? DecodingError {
                        completionHandler?(.failure(FlagsmithError.decoding(error)))
                    } else {
                        completionHandler?(.failure(FlagsmithError.unhandled(error)))
                    }
                }
            }
        }
    }
    
    // MARK: URLSessionDelegate
    
    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        serialAccessQueue.sync {
            if let message = String(data: data, encoding: .utf8) {
                processSSEData(message)
                reconnectionDelay.reset()
            }
        }
    }
    
    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        serialAccessQueue.sync {
            if task != dataTask {
                return
            }
            
            // If the connection times out or we have no error passed to us it's pretty common, so just reconnect
            if let error = error {
                if let error = error as? URLError, error.code == .timedOut {
                    if let completionHandler = completionHandler {
                        start(completion: completionHandler)
                    }
                }
            } else if error == nil {
                start(completion: self.completionHandler!)
                return
            }
            
            // Otherwise reconnect with increasing delay using the reconnectionTimer so that we don't load the phone / server
            serialAccessQueue.asyncAfter(deadline: .now() + reconnectionDelay.nextDelay()) { [weak self] in
                if let self {
                    self.start(completion: self.completionHandler!)
                }
            }
        }
    }
    
    // MARK: Public Methods
    
    func start(completion: @escaping CompletionHandler<FlagEvent>) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.failure(FlagsmithError.apiKey))
            return
        }
        
        guard let completeEventSourceUrl = URL(string: "\(baseURL.absoluteString)sse/environments/\(apiKey)/stream") else {
            completion(.failure(FlagsmithError.apiURL("Invalid event source URL")))
            return
        }
        
        var request = URLRequest(url: completeEventSourceUrl)
        request.setValue("text/event-stream, application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        completionHandler = completion
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    func stop() {
        dataTask?.cancel()
        completionHandler = nil
    }
}
