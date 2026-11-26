//
//  RequestItem.swift
//  RCProxyCore
//
//  Created by Rémi Caroff on 03/02/2023.
//

import Foundation

/// A single query parameter of a recorded request.
public struct QueryParameterItem: Codable, Identifiable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var value: String

    public init(id: String, name: String, value: String) {
        self.id = id
        self.name = name
        self.value = value
    }
}

/// A recorded HTTP request, with its response once it has been received.
///
/// This is a plain value: it can be freely passed between threads, stored, and sent to RCProxy Desktop.
public struct RequestItem: Codable, Identifiable, Sendable {
    public var id: String
    /// The date the request was sent.
    public var date: Date
    /// The complete URL, query string included.
    public var fullURL: String
    public var method: String
    public var requestHeaders: [String: String]
    public var requestBodyData: Data?
    public var responseHeaders: [String: String]
    public var responseBodyData: Data?
    /// The HTTP status code, or `0` while the response has not been received (or if the request failed).
    public var statusCode: Int
    public var cURL: String
    /// Time elapsed between the request being sent and its completion.
    public var duration: TimeInterval?
    /// The transport error, when the request failed without an HTTP response.
    public var errorDescription: String?

    public init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        fullURL: String,
        method: String,
        requestHeaders: [String: String] = [:],
        requestBodyData: Data? = nil,
        responseHeaders: [String: String] = [:],
        responseBodyData: Data? = nil,
        statusCode: Int = 0,
        cURL: String = "",
        duration: TimeInterval? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.date = date
        self.fullURL = fullURL
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBodyData = requestBodyData
        self.responseHeaders = responseHeaders
        self.responseBodyData = responseBodyData
        self.statusCode = statusCode
        self.cURL = cURL
        self.duration = duration
        self.errorDescription = errorDescription
    }
}

// MARK: - Derived values

public extension RequestItem {

    /// The URL without its query string, e.g. `https://api.example.com/v1/users`.
    var url: String {
        guard let components = URLComponents(string: fullURL), let host = components.host else {
            return fullURL
        }
        let scheme = components.scheme.map { "\($0)://" } ?? ""
        let port = components.port.map { ":\($0)" } ?? ""
        return "\(scheme)\(host)\(port)\(components.path)"
    }

    var host: String {
        URLComponents(string: fullURL)?.host ?? ""
    }

    /// The path of the URL, e.g. `/v1/users`.
    var relativePath: String {
        URLComponents(string: fullURL)?.path ?? ""
    }

    var queryParameters: [QueryParameterItem] {
        guard let queryItems = URLComponents(string: fullURL)?.queryItems else { return [] }
        return queryItems.enumerated().map { index, item in
            QueryParameterItem(id: "\(index)-\(item.name)", name: item.name, value: item.value ?? "")
        }
    }

    /// `true` once a response (or an error) has been received.
    var isCompleted: Bool {
        statusCode != 0 || errorDescription != nil
    }

    /// `true` for HTTP errors (status >= 400) and for requests without any response.
    /// This mirrors the "errors" filter of the in-app UI.
    var isError: Bool {
        statusCode >= 400 || statusCode == 0
    }

    /// `true` for responses with a status code below 400.
    var isSuccess: Bool {
        statusCode != 0 && statusCode < 400
    }
}
