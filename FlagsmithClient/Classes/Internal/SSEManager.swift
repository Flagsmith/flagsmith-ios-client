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

/// Handles interaction with the Flagsmith SSE real-time API.
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
    
    // private var streamTask: Task<Void, Error>? = nil
    
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
    
//    // Enable real time updates
//    private var _enableRealtimeUpdates = false
//    var enableRealtimeUpdates: Bool {
//        get {
//            propertiesSerialAccessQueue.sync { _enableRealtimeUpdates }
//        }
//        set {
//            if (apiKey == nil) {
//                print("API Key must be set before enabling real time updates")
//                return
//            }
//
//            propertiesSerialAccessQueue.sync {
//                _enableRealtimeUpdates = newValue
//                
//                //TODO: Kick off the real time updates
//            }
//        }
//    }
    
    private var completionHandler: CompletionHandler<FlagEvent>?
    private let serialAccessQueue = DispatchQueue(label: "sseFlagsmithSerialAccessQueue", qos: .default)
    let propertiesSerialAccessQueue = DispatchQueue(label: "ssePropertiesSerialAccessQueue", qos: .default)

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        
        //TODO: Check session against examples
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    // Helper function to process SSE data
    private func processSSEData(_ data: String) {
        // Parse and handle SSE events here
        print("Received SSE data: \(data)")
        //TODO: Decode the data
    }
    
    //MARK: URLSessionDelegate

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        serialAccessQueue.sync {
            // Print what's going on
            print("SSE received data: \(data)")
            // This is where we need to handle the data
            if let message = String(data: data, encoding: .utf8) {
                processSSEData(message)
            }
        }
    }

//    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive _: URLResponse,
//                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
//    {
//        completionHandler(.allow)
//    }
    
    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        serialAccessQueue.sync {
            if task != dataTask {
                return
            }
            
            if let error = error {
                // Handle SSE error
                print("Error in SSE connection: \(error)")
            } else if let completionHandler = completionHandler {
                // Reconnect to the SSE
                start(completion: completionHandler)
            }
        }
    }
    
//    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse,
//                    completionHandler: @Sendable @escaping (CachedURLResponse?) -> Void)
//    {
//        // Don't cache the response for the SSE requests
//        completionHandler(nil)
//    }
    
    //MARK: Public Methods
    
    func start(completion: @escaping CompletionHandler<FlagEvent>) {
        guard completionHandler == nil else {
            completion(.failure(FlagsmithError.sseAlreadyStarted))
            return
        }
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.failure(FlagsmithError.apiKey))
            return
        }
        
        guard let completeEventSourceUrl = URL(string: "\(baseURL)sse/environments/\(apiKey)/stream") else {
            completion(.failure(FlagsmithError.apiURL("Invalid event source URL")))
            return
        }
        
        var request = URLRequest(url: completeEventSourceUrl)
        request.setValue("text/event-stream, application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    func stop() {
        dataTask?.cancel()
        completionHandler = nil;
    }
}
