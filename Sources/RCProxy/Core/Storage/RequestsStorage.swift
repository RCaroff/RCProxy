//
//  RequestsStorage.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation
import RCProxyCore

/// What is known about a request once it is over: its response, or the reason why it failed.
struct RequestCompletion: Sendable {
    var statusCode: Int = 0
    var headers: [String: String] = [:]
    var body: Data?
    var duration: TimeInterval?
    var errorDescription: String?

    func apply(to item: inout RequestItem) {
        item.statusCode = statusCode
        item.responseHeaders = headers
        item.responseBodyData = body
        item.duration = duration
        item.errorDescription = errorDescription
    }
}

/// A place where the recorded requests are kept.
///
/// Storages are called from arbitrary threads: every implementation is an actor,
/// and only exchanges `RequestItem` values, which are safe to pass around.
protocol RequestsStorage: Sendable {
    /// The stored requests, most recent first.
    func fetch() async -> [RequestItem]
    func insert(_ item: RequestItem) async
    /// Completes a stored request. Returns the updated request, or `nil` if it is not stored anymore.
    @discardableResult
    func complete(id: String, with completion: RequestCompletion) async -> RequestItem?
    func clear() async
}

enum RequestsStorageDefaults {
    static let maxRequestsCount = 100

    /// `0` has never been a meaningful limit: it falls back to the default one.
    static func normalized(_ maxRequestsCount: UInt) -> Int {
        maxRequestsCount == 0 ? Self.maxRequestsCount : Int(clamping: maxRequestsCount)
    }
}
