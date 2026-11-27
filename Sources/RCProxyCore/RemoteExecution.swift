//
//  RemoteExecution.swift
//  RCProxyCore
//
//  A request handed over to a viewer, which performs it instead of the app.
//

import Foundation

/// A request the app asks a viewer to perform on its behalf.
///
/// Once RCProxy Desktop is connected and asks for it, the app does not talk to the network anymore:
/// every request travels to the Mac, which performs it (or answers it with a mock) and sends the result back.
public struct RemoteExecutionRequest: Codable, Sendable, Hashable, Identifiable {
    /// Same identifier as the `RequestItem` recorded for this request.
    public var id: String
    public var url: String
    public var method: String
    public var headers: [String: String]
    public var body: Data?
    /// Seconds after which the request should be given up.
    public var timeout: TimeInterval

    public init(
        id: String,
        url: String,
        method: String,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 60
    ) {
        self.id = id
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// What a viewer answers to a `RemoteExecutionRequest`: an HTTP response, or a failure.
public struct RemoteExecutionResult: Codable, Sendable, Hashable, Identifiable {
    /// The identifier of the request this answers.
    public var id: String
    /// `0` when no HTTP response was received.
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data?
    /// Set when the request failed before any HTTP response.
    public var errorDescription: String?
    /// The `URLError` code of the failure, when there is one.
    public var errorCode: Int?

    public init(
        id: String,
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data? = nil,
        errorDescription: String? = nil,
        errorCode: Int? = nil
    ) {
        self.id = id
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.errorDescription = errorDescription
        self.errorCode = errorCode
    }

    /// A failure without any HTTP response.
    public static func failure(id: String, _ error: any Error) -> RemoteExecutionResult {
        let nsError = error as NSError
        return RemoteExecutionResult(
            id: id,
            statusCode: 0,
            errorDescription: error.localizedDescription,
            errorCode: nsError.domain == NSURLErrorDomain ? nsError.code : nil
        )
    }

    public var isFailure: Bool { statusCode == 0 }
}
