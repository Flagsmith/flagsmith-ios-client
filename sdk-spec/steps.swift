// Steps for the Flagsmith SDK behavioural spec: https://github.com/Flagsmith/sdk-spec

import FlagsmithClient
import Foundation

/// The SDK only offers the `Flagsmith.shared` singleton, so a client is the configuration applied to
/// it before each call. The harness runs one step at a time, so calls never interleave.
public struct Client {
    let environmentKey: String
    let apiURL: URL

    var flagsmith: Flagsmith {
        let flagsmith = Flagsmith.shared
        flagsmith.apiKey = environmentKey
        flagsmith.baseURL = apiURL
        return flagsmith
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
