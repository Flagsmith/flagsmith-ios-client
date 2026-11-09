// Steps for the Flagsmith SDK behavioural spec: https://github.com/Flagsmith/sdk-spec

import FlagsmithClient
import Foundation

/// The SDK only offers the `Flagsmith.shared` singleton, so a client is the configuration applied to
/// it before each call. The harness runs one step at a time, so calls never interleave.
public struct Client {
    let environmentKey: String
    let apiURL: URL
    var eventsURL: URL?

    var flagsmith: Flagsmith {
        let flagsmith = Flagsmith.shared
        flagsmith.apiKey = environmentKey
        flagsmith.baseURL = apiURL
        if let eventsURL {
            flagsmith.eventsBaseURL = eventsURL
        }
        if flagsmith.enableEvents != (eventsURL != nil) {
            flagsmith.enableEvents = eventsURL != nil
        }
        return flagsmith
    }
}

public struct StepArgumentError: Error {
    let description: String
}

/// Wraps a step function of five parameters for the harness, whose own `step` overloads take up to four: the
/// client, then each argument decoded to its parameter type.
public func step<StepClient, A: Decodable, B: Decodable, C: Decodable, D: Decodable, R, Argument: Encodable>(
    _ function: @escaping (StepClient, A, B, C, D) async throws -> R
) -> (Any?, [Argument]) async throws -> Any {
    { client, args in
        guard let client = client as? StepClient, args.count == 4 else {
            throw StepArgumentError(description: "The step function takes a \(StepClient.self) and 4 arguments")
        }
        func decode<T: Decodable>(_ arg: Argument) throws -> T {
            try JSONDecoder().decode(T.self, from: JSONEncoder().encode(arg))
        }
        return try await function(client, decode(args[0]), decode(args[1]), decode(args[2]), decode(args[3]))
    }
}

public struct SpecFlag: Encodable {
    let feature: String
    let enabled: Bool
    let value: TypedValue

    init(_ flag: Flag) {
        feature = flag.feature.name
        enabled = flag.enabled
        value = flag.value
    }
}

// Create the SDK client
public func createClient(environmentKey: String, apiUrl: String) throws -> Client {
    guard let apiURL = URL(string: apiUrl) else { throw FlagsmithError.apiURL(apiUrl) }
    return Client(environmentKey: environmentKey, apiURL: apiURL)
}

// Create the SDK client with events enabled
public func createClientWithEvents(environmentKey: String, apiUrl: String, eventsApiUrl: String) throws -> Client {
    var client = try createClient(environmentKey: environmentKey, apiUrl: apiUrl)
    guard let eventsURL = URL(string: eventsApiUrl) else { throw FlagsmithError.apiURL(eventsApiUrl) }
    client.eventsURL = eventsURL
    return client
}

// When the application gets the environment flags
public func getEnvironmentFlags(_ client: Client) async throws -> [SpecFlag] {
    try await client.flagsmith.getFeatureFlags().map(SpecFlag.init)
}

// When the application gets the flags for identity "{identifier}" with traits:
public func getIdentityFlags(_ client: Client, identifier: String, traits: [String: TypedValue]) async throws -> [SpecFlag] {
    let traits = traits.map { Trait(key: $0.key, value: $0.value) }
    let flags = try await withCheckedThrowingContinuation { continuation in
        client.flagsmith.getFeatureFlags(forIdentity: identifier, traits: traits) { continuation.resume(with: $0) }
    }
    return flags.map(SpecFlag.init)
}

// When the application gets the experiment flag "{feature}" for identity "{identifier}" with traits:
public func getExperimentFlag(_ client: Client, feature: String, identifier: String,
                              traits: [String: TypedValue]) async throws -> [SpecFlag]
{
    let traits = traits.map { Trait(key: $0.key, value: $0.value) }
    let flag = try await client.flagsmith.getExperimentFlag(withID: feature, forIdentity: identifier, traits: traits)
    return flag.map { [SpecFlag($0)] } ?? []
}

// When the application tracks event "{event}" for identity "{identifier}" with value {value} and metadata:
public func trackEvent(_ client: Client, event: String, identifier: String, value: TypedValue, metadata: [String: TypedValue]) throws {
    try client.flagsmith.trackEvent(event, forIdentity: identifier, value: value, metadata: metadata)
}

// When the application tracks an exposure of feature "{feature}" for identity "{identifier}" with value {value} and metadata:
public func trackExposureEvent(_ client: Client, feature: String, identifier: String, value: TypedValue, metadata: [String: TypedValue]) {
    client.flagsmith.trackExposureEvent(forFeature: feature, forIdentity: identifier, value: value, metadata: metadata)
}
