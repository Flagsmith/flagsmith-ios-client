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
/// Sends every `flushPeriod` seconds, once `maxBuffer` events are buffered, and on `flush`.
/// Exposures are deduplicated within a batch. A failed batch is retried once, then dropped.
final class FlagsmithEvents: @unchecked Sendable {
    static let flagExposureEvent = "$flag_exposure"

    /// Sends a batch of events to the events API at a base URL.
    typealias Send = @Sendable (_ events: [Event], _ baseURL: URL,
                                _ completion: @Sendable @escaping (Result<Void, any Error>) -> Void) -> Void

    private let send: Send
    private let queue = DispatchQueue(label: "flagsmithEventsQueue", qos: .utility)
    private let uploads = DispatchGroup()

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
    let retryDelay: TimeInterval

    private var buffer: [Event] = []
    private var exposureKeys: Set<[String?]> = []
    private var timer: (any DispatchSourceTimer)?

    init(maxBuffer: Int = 1000, retryDelay: TimeInterval = 1, send: @escaping Send) {
        self.maxBuffer = maxBuffer
        self.retryDelay = retryDelay
        self.send = send
    }

    convenience init(apiManager: APIManager) {
        self.init { events, baseURL, completion in
            apiManager.request(.postEvents(events: events), baseURL: baseURL, completion: completion)
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

    /// Sends the buffered events, then calls `completion` once every send in progress has finished.
    func flush(completion: (@Sendable () -> Void)? = nil) {
        queue.sync { sendBuffer() }
        if let completion = completion {
            uploads.notify(queue: .global(), execute: completion)
        }
    }

    private func record(_ event: Event) {
        queue.sync {
            guard _enabled else { return }
            if event.event == Self.flagExposureEvent {
                // The experiment is part of the key, so that a new experiment on the same flag and variant is recorded.
                let key = [event.featureName, event.identifier, event.value, event.metadata["experiment_id"]?.description]
                guard exposureKeys.insert(key).inserted else { return }
            }
            buffer.append(event)
            if buffer.count >= maxBuffer {
                sendBuffer()
            }
        }
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

    /// Must be called on `queue`.
    private func sendBuffer() {
        guard !buffer.isEmpty else { return }
        let events = buffer
        buffer = []
        exposureKeys = []
        uploads.enter()
        upload(events, baseURL: _baseURL, isRetry: false)
    }

    private func upload(_ events: [Event], baseURL: URL, isRetry: Bool) {
        send(events, baseURL) { @Sendable [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.uploads.leave()
            case let .failure(error) where !isRetry:
                print("Flagsmith - Sending events failed, retrying: \(error.localizedDescription)")
                self.queue.asyncAfter(deadline: .now() + self.retryDelay) {
                    self.upload(events, baseURL: baseURL, isRetry: true)
                }
            case let .failure(error):
                print("Flagsmith - Sending events failed, dropping \(events.count) events: \(error.localizedDescription)")
                self.uploads.leave()
            }
        }
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
            timer.setEventHandler { [weak self] in self?.sendBuffer() }
            timer.resume()
            self.timer = timer
        }
    }
}
