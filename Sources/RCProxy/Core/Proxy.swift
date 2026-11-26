//
//  Proxy.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation
import os
import RCProxyCore

/// Intercepts the HTTP(S) requests, performs them with `RCProxy.urlSession`, and records them.
final class RCProxyProtocol: URLProtocol, @unchecked Sendable {

    private static let handledKey = "is_handled"

    private struct State {
        var dataTask: URLSessionDataTask?
        var isStopped = false
    }

    /// `startLoading`, `stopLoading` and the completion handler run on different threads.
    private let state = OSAllocatedUnfairLock(initialState: State())

    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return URLProtocol.property(forKey: handledKey, in: request) as? Bool != true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let id = UUID().uuidString
        let startDate = Date()

        // The body is exposed as a stream, which can only be read once: read it here,
        // then hand the data to both the recorder and the request that is actually sent.
        var forwardedRequest = request
        let body = request.httpBody ?? request.bodyStream()
        if request.httpBody == nil, let body, !body.isEmpty {
            forwardedRequest.httpBodyStream = nil
            forwardedRequest.httpBody = body
        }

        RequestRecorder.shared.requestStarted(
            RequestItem(id: id, urlRequest: request, body: body, date: startDate)
        )

        guard let mutableRequest = (forwardedRequest as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        let task = RCProxy.urlSession.dataTask(with: mutableRequest as URLRequest) { [self] data, response, error in
            let duration = Date().timeIntervalSince(startDate)
            forward(data: data, response: response, error: error)
            record(id: id, data: data, response: response, error: error, duration: duration)
        }

        let isStopped = state.withLock { state -> Bool in
            state.dataTask = task
            return state.isStopped
        }
        if isStopped {
            task.cancel()
        } else {
            task.resume()
        }
    }

    override func stopLoading() {
        let task = state.withLock { state -> URLSessionDataTask? in
            state.isStopped = true
            return state.dataTask
        }
        task?.cancel()
    }

    /// Hands the result over to the URL loading system.
    private func forward(data: Data?, response: URLResponse?, error: Error?) {
        // Once the load has been stopped, the client must not be called anymore.
        guard !state.withLock({ $0.isStopped }) else { return }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    private func record(id: String, data: Data?, response: URLResponse?, error: Error?, duration: TimeInterval) {
        var completion = RequestCompletion(duration: duration)
        if let response = response as? HTTPURLResponse {
            completion.statusCode = response.statusCode
            completion.headers = response.stringHeaders
            completion.body = data
        }
        if let error {
            completion.errorDescription = error.localizedDescription
        } else if completion.statusCode == 0 {
            completion.errorDescription = "No HTTP response"
        }
        RequestRecorder.shared.requestCompleted(id: id, completion: completion)
    }
}

extension HTTPURLResponse {
    /// The headers as strings. Never fails, whatever the types found in `allHeaderFields`.
    var stringHeaders: [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in allHeaderFields {
            headers["\(key)"] = "\(value)"
        }
        return headers
    }
}
