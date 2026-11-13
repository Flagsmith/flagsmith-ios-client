//
//  FlagsmithEvents.swift
//  FlagsmithClient
//

import Foundation

/// An experimentation event, as sent to Flagsmith's events API.
struct Event: Encodable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey {
        case event
        case featureName = "feature_name"
        case identifier
        case value
        case traits
        case metadata
        case timestamp
    }

    let event: String
    let featureName: String?
    let identifier: String?
    let value: String?
    let traits: [String: TypedValue]?
    let metadata: [String: TypedValue]
    /// Milliseconds since the Unix epoch.
    let timestamp: Int

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encode(featureName, forKey: .featureName)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(value, forKey: .value)
        try container.encode(traits, forKey: .traits)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

/// Batches experimentation events to Flagsmith's events API.
///
/// Sends every `flushPeriod` seconds, once `maxBuffer` events are buffered, and on `flush`. Exposures are
/// deduplicated within a batch. One batch is in flight at a time, and each request times out after
/// `requestTimeout` seconds.
///
/// A batch is retried on a network error, a timeout, or a 408, 429, 500, 502, 503 or 504, for up to
/// `maxAttempts` attempts, backing off from `retryDelay` seconds, doubling, with full jitter. A batch that
/// still fails is kept, ahead of newer events, for the next flush, unless its last attempt got a 500. Any
/// other status drops the batch. A 401 or 403 drops the buffer, and makes tracking a no-op until the
/// environment key changes. The buffer holds `maxBuffer` events, and drops the oldest when full.
final class FlagsmithEvents: @unchecked Sendable {
    static let flagExposureEvent = "$flag_exposure"

    /// Sends a batch of events to the events API at a base URL, and returns a function cancelling the request.
    ///
    /// The completion receives the HTTP status code of the response, or the error that prevented one.
    typealias Send = @Sendable (_ events: [Event], _ baseURL: URL,
                                _ completion: @Sendable @escaping (Result<Int, any Error>) -> Void) -> @Sendable () -> Void

    private let send: Send
    private let queue = DispatchQueue(label: "flagsmithEventsQueue", qos: .utility)

    private var _enabled = false
    /// Indicates if events are sent. Events tracked while disabled are dropped.
    var enabled: Bool {
        get { queue.sync { _enabled } }
        set {
            queue.sync { _enabled = newValue }
            setupTimer()
        }
    }

    private var _baseURL = URL(string: "https://events.api.flagsmith.com/")!
    /// Base URL of the events API.
    var baseURL: URL {
        get { queue.sync { _baseURL } }
        set { queue.sync { _baseURL = newValue } }
    }

    private var _flushPeriod: Int = 10
    /// How often buffered events are sent (in seconds).
    var flushPeriod: Int {
        get { queue.sync { _flushPeriod } }
        set {
            queue.sync { _flushPeriod = newValue }
            setupTimer()
        }
    }

    let maxBuffer: Int
    let maxAttempts: Int
    let retryDelay: TimeInterval
    let requestTimeout: TimeInterval
    private let jitter: @Sendable (TimeInterval) -> TimeInterval

    private var buffer: [Event] = []
    private var exposureKeys: Set<[String?]> = []
    private var timer: (any DispatchSourceTimer)?
    /// Indicates if a batch is being sent, retries included.
    private var sending = false
    /// The request in flight, if any, and how to cancel it.
    private var request: (id: Int, cancel: @Sendable () -> Void)?
    private var lastRequestID = 0
    /// Indicates if a batch that failed is waiting for the next flush.
    private var held = false
    /// Indicates if the events API refused the environment key.
    private var unauthorised = false
    /// Changes on `close`, so that the sends started before it end.
    private var generation = 0
    /// Called on `queue` once no batch is being sent.
    private var idleHandlers: [() -> Void] = []

    init(maxBuffer: Int = 1000, maxAttempts: Int = 3, retryDelay: TimeInterval = 1, requestTimeout: TimeInterval = 3,
         jitter: @escaping @Sendable (TimeInterval) -> TimeInterval = { .random(in: 0 ... $0) },
         send: @escaping Send)
    {
        self.maxBuffer = maxBuffer
        self.maxAttempts = maxAttempts
        self.retryDelay = retryDelay
        self.requestTimeout = requestTimeout
        self.jitter = jitter
        self.send = send
    }

    convenience init(apiManager: APIManager) {
        self.init { events, baseURL, completion in
            apiManager.postEvents(events, baseURL: baseURL, completion: completion)
        }
    }

    deinit {
        timer?.cancel()
    }

    func trackEvent(_ event: String, identifier: String?, value: TypedValue?,
                    traits: [String: TypedValue]?, metadata: [String: TypedValue]?)
    {
        record(Event(event: event, featureName: nil, identifier: identifier, value: Self.eventValue(value),
                     traits: traits, metadata: Self.eventMetadata(metadata), timestamp: Self.now()))
    }

    func trackExposureEvent(featureName: String, identifier: String, value: TypedValue?,
                            traits: [String: TypedValue]?, metadata: [String: TypedValue]?)
    {
        record(Event(event: Self.flagExposureEvent, featureName: featureName, identifier: identifier,
                     value: Self.eventValue(value), traits: traits, metadata: Self.eventMetadata(metadata),
                     timestamp: Self.now()))
    }

    /// Tracks the exposure of an identity to a flag, if the identity is enrolled in a running experiment on it.
    func trackExposure(to flag: Flag, identifier: String, traits: [String: TypedValue]?) {
        guard flag.enabled, let experiment = flag.experiment, experiment.inExperiment, let variant = flag.variant else {
            return
        }
        trackExposureEvent(featureName: flag.feature.name, identifier: identifier, value: .string(variant),
                           traits: traits, metadata: ["experiment_id": .int(experiment.id)])
    }

    /// Sends the buffered events, then calls `completion` once they have been sent, retries included, or kept or
    /// dropped after failing to send.
    ///
    /// A batch already being sent is waited for first. If it fails, it is kept for the next flush rather than sent again.
    func flush(completion: (@Sendable () -> Void)? = nil) {
        queue.sync {
            held = false
            whenIdle { [self] in
                if !held {
                    sendBuffer()
                }
                whenIdle {
                    if let completion = completion {
                        DispatchQueue.global().async(execute: completion)
                    }
                }
            }
        }
    }

    /// Flushes the buffered events, then stops sending events, calling `completion` once done or once `timeout`
    /// seconds have passed, whichever comes first.
    ///
    /// When the timeout passes, the request in flight is cancelled, and the events not sent are dropped.
    /// Setting `enabled` sends events again.
    func close(timeout: TimeInterval, completion: (@Sendable () -> Void)? = nil) {
        queue.sync {
            let closing = generation
            let stop: @Sendable () -> Void = { [self] in
                guard generation == closing else { return }
                generation += 1
                request?.cancel()
                request = nil
                sending = false
                held = false
                buffer = []
                exposureKeys = []
                _enabled = false
                timer?.cancel()
                timer = nil
                if let completion = completion {
                    DispatchQueue.global().async(execute: completion)
                }
                runIdleHandlers()
            }
            held = false
            whenIdle { [self] in
                sendBuffer()
                whenIdle(stop)
            }
            queue.asyncAfter(deadline: .now() + timeout, execute: stop)
        }
    }

    /// Lets events be tracked again after the events API refused the environment key, once that key has changed.
    func environmentKeyChanged() {
        queue.sync { unauthorised = false }
    }

    private func record(_ event: Event) {
        queue.sync {
            guard _enabled, !unauthorised else { return }
            if event.event == Self.flagExposureEvent {
                // The experiment is part of the key, so that a new experiment on the same flag and variant is recorded.
                let key = [event.featureName, event.identifier, event.value, event.metadata["experiment_id"]?.description]
                guard exposureKeys.insert(key).inserted else { return }
            }
            if buffer.count >= maxBuffer, canSendFullBuffer {
                sendBuffer()
            }
            if buffer.count >= maxBuffer {
                buffer.removeFirst(buffer.count - maxBuffer + 1)
            }
            buffer.append(event)
            if buffer.count >= maxBuffer, canSendFullBuffer {
                sendBuffer()
            }
        }
    }

    /// Must be called on `queue`.
    private var canSendFullBuffer: Bool {
        !sending && !held
    }

    private static func eventValue(_ value: TypedValue?) -> String? {
        value.flatMap { $0 == .null ? nil : $0.description }
    }

    private static func eventMetadata(_ metadata: [String: TypedValue]?) -> [String: TypedValue] {
        (metadata ?? [:]).merging(["sdk_version": .string(Router.sdkVersion)]) { _, sdkVersion in sdkVersion }
    }

    /// Milliseconds since the Unix epoch.
    private static func now() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    /// Runs `handler` once no batch is being sent. Must be called on `queue`.
    private func whenIdle(_ handler: @escaping () -> Void) {
        if sending {
            idleHandlers.append(handler)
        } else {
            handler()
        }
    }

    /// Must be called on `queue`.
    private func runIdleHandlers() {
        let handlers = idleHandlers
        idleHandlers = []
        handlers.forEach { $0() }
    }

    /// Sends the buffered events, unless a batch is being sent already. Must be called on `queue`.
    private func sendBuffer() {
        guard !buffer.isEmpty, !sending, !unauthorised else { return }
        let events = buffer
        buffer = []
        exposureKeys = []
        sending = true
        upload(events, attempt: 1, generation: generation)
    }

    /// Must be called on `queue`.
    private func upload(_ events: [Event], attempt: Int, generation: Int) {
        guard generation == self.generation else { return }
        lastRequestID += 1
        let id = lastRequestID
        let cancel = send(events, _baseURL) { @Sendable [weak self] result in
            guard let self = self else { return }
            self.queue.async {
                self.uploaded(events, attempt: attempt, generation: generation, requestID: id, result: result)
            }
        }
        // The completion runs on `queue`, so after this.
        request = (id, cancel)
        queue.asyncAfter(deadline: .now() + requestTimeout) { [weak self] in
            guard let self = self, self.request?.id == id else { return }
            self.request?.cancel()
            self.uploaded(events, attempt: attempt, generation: generation, requestID: id,
                          result: .failure(FlagsmithError.unhandled(URLError(.timedOut))))
        }
    }

    /// Must be called on `queue`.
    private func uploaded(_ events: [Event], attempt: Int, generation: Int, requestID: Int, result: Result<Int, any Error>) {
        guard generation == self.generation, request?.id == requestID else { return }
        request = nil
        switch Outcome(result) {
        case .delivered:
            break
        case .unauthorised:
            print("Flagsmith - The events API refused the environment key, so events are no longer tracked: \(result)")
            unauthorised = true
            buffer = []
            exposureKeys = []
        case .rejected:
            print("Flagsmith - The events API rejected \(events.count) events, dropping them: \(result)")
        case .retryable where attempt < maxAttempts:
            let delay = jitter(retryDelay * pow(2, Double(attempt - 1)))
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.upload(events, attempt: attempt + 1, generation: generation)
            }
            return
        case .retryable(keep: false):
            print("Flagsmith - Sending events failed, dropping \(events.count) events: \(result)")
        case .retryable(keep: true):
            print("Flagsmith - Sending events failed, keeping \(events.count) events for the next flush: \(result)")
            buffer = events + buffer
            if buffer.count > maxBuffer {
                buffer.removeFirst(buffer.count - maxBuffer)
            }
            held = true
        }
        sending = false
        runIdleHandlers()
    }

    /// Invalidates and re-schedules the timer for sending events, while enabled.
    private func setupTimer() {
        queue.sync {
            timer?.cancel()
            timer = nil
            guard _enabled, _flushPeriod > 0 else {
                sendBuffer()
                return
            }
            let period = DispatchTimeInterval.seconds(_flushPeriod)
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + period, repeating: period)
            timer.setEventHandler { [weak self] in
                self?.held = false
                self?.sendBuffer()
            }
            timer.resume()
            self.timer = timer
        }
    }
}

extension FlagsmithEvents {
    /// What a request sending a batch came to.
    enum Outcome: Equatable {
        /// The events API accepted the batch.
        case delivered
        /// The request failed in a way that may not last, and is retried. `keep` tells if the batch is kept for
        /// the next flush once its attempts run out.
        case retryable(keep: Bool)
        /// The events API rejected the batch, which is dropped.
        case rejected
        /// The events API refused the environment key.
        case unauthorised

        init(_ result: Result<Int, any Error>) {
            switch result {
            case let .success(status):
                switch status {
                case 200 ..< 300: self = .delivered
                case 401, 403: self = .unauthorised
                case 408, 429, 502, 503, 504: self = .retryable(keep: true)
                case 500: self = .retryable(keep: false)
                default: self = .rejected
                }
            case let .failure(error):
                // A network error or a timeout may not last; a request that could not be made at all would fail again.
                if case FlagsmithError.unhandled = error {
                    self = .retryable(keep: true)
                } else {
                    self = .rejected
                }
            }
        }
    }
}
