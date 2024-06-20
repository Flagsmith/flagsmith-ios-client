//
//  FlagsmithError.swift
//  FlagsmithClient
//
//  Created by Richard Piazza on 3/18/22.
//

import Foundation

/// All errors that can be encountered while using the **FlagsmithClient**
public enum FlagsmithError: LocalizedError, Sendable {
    /// API Key was not provided or invalid.
    case apiKey
    /// API URL was invalid.
    case apiURL(String)
    /// API request could not be encoded.
    case encoding(EncodingError)
    /// API Response status code was not expected.
    case statusCode(Int)
    /// API Response could not be decoded.
    case decoding(DecodingError)
    /// Unknown or unhandled error was encountered.
    case unhandled(any Error)
    /// Invalid argument error
    case invalidArgument(String)

    public var errorDescription: String? {
        switch self {
        case .apiKey:
            return "API Key was not provided or invalid"
        case let .apiURL(path):
            return "API URL '\(path)' was invalid"
        case let .encoding(error):
            return "API Request could not be encoded: \(error.localizedDescription)"
        case let .statusCode(code):
            return "API Status Code '\(code)' was not expected."
        case let .decoding(error):
            return "API Response could not be decoded: \(error.localizedDescription)"
        case let .unhandled(error):
            return "An unknown or unhandled error was encountered: \(error.localizedDescription)"
        case let .invalidArgument(error):
            return "Invalid argument error: \(error)"
        }
    }

    /// Initialize a `FlagsmithError` using an existing `Swift.Error`.
    ///
    /// The error provided will be processed in several ways:
    /// * as `FlagsmithError`: The instance will be directly assigned.
    /// * as `EncodingError`: `.encoding()` error will be created.
    /// * as `DecodingError`: `.decoding()` error will be created.
    /// * default: `.unhandled()` error will be created.
    internal init(_ error: any Error) {
        switch error {
        case let flagsmithError as FlagsmithError:
            self = flagsmithError
        case let encodingError as EncodingError:
            self = .encoding(encodingError)
        case let decodingError as DecodingError:
            self = .decoding(decodingError)
        default:
            self = .unhandled(error)
        }
    }
}
