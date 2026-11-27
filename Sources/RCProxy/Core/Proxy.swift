//
//  Proxy.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation
import os
import RCProxyCore

/// Intercepts the HTTP(S) requests, performs them with `RCProxy.urlSession` (or hands them over to
/// RCProxy Desktop when it asked for it), and records them.
final class RCProxyProtocol: URLProtocol, @unchecked Sendable {

    private static let handledKey = "is_handled"

    private struct State {
        var dataTask: URLSessionDataTask?
        var isStopped = false
        /// Set while RCProxy Desktop is performing the request.
        var delegatedID: String?
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

        // When RCProxy Desktop asked for it, the Mac performs the request (or mocks it) instead of the app.
        let delegated = RemoteExecutionRequest(
            id: id,
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "GET",
            headers: DelegatedRequest.headers(for: request),
            body: body,
            timeout: request.timeoutInterval
        )
        state.withLock { $0.delegatedID = id }
        let local = forwardedRequest
        DesktopStreamer.shared.execute(delegated) { [self] result in
            state.withLock { $0.delegatedID = nil }
            if let result {
                finish(id: id, startDate: startDate, with: result)
            } else {
                // Nobody to perform it, or the Mac went away: the app does it itself.
                performLocally(local, id: id, startDate: startDate)
            }
        }
    }

    private func performLocally(_ forwardedRequest: URLRequest, id: String, startDate: Date) {
        guard !state.withLock({ $0.isStopped }) else { return }
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

    /// Hands the answer of RCProxy Desktop over to the URL loading system, as if the app had received it.
    private func finish(id: String, startDate: Date, with result: RemoteExecutionResult) {
        let duration = Date().timeIntervalSince(startDate)
        guard !result.isFailure, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: result.statusCode, httpVersion: "HTTP/1.1", headerFields: result.headers) else {
            let error = NSError(
                domain: NSURLErrorDomain,
                code: result.errorCode ?? NSURLErrorUnknown,
                userInfo: [NSLocalizedDescriptionKey: result.errorDescription ?? "The request failed on RCProxy Desktop."]
            )
            forward(data: nil, response: nil, error: error)
            record(id: id, data: nil, response: nil, error: error, duration: duration)
            return
        }
        DelegatedRequest.storeCookies(of: response, for: request)
        let data = result.body ?? Data()
        forward(data: data, response: response, error: nil)
        record(id: id, data: data, response: response, error: nil, duration: duration)
    }

    override func stopLoading() {
        let (task, delegatedID) = state.withLock { state -> (URLSessionDataTask?, String?) in
            state.isStopped = true
            return (state.dataTask, state.delegatedID)
        }
        task?.cancel()
        if let delegatedID {
            DesktopStreamer.shared.cancelExecution(id: delegatedID)
        }
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

/// What the URL loading system adds to a request by itself, and that a request performed elsewhere would miss.
enum DelegatedRequest {

    /// The headers of the request, plus the cookies, user agent and languages the app would have sent.
    static func headers(for request: URLRequest) -> [String: String] {
        var headers = request.allHTTPHeaderFields ?? [:]
        func has(_ name: String) -> Bool {
            headers.keys.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        }

        if request.httpShouldHandleCookies, !has("Cookie"), let url = request.url,
           let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty {
            headers.merge(HTTPCookie.requestHeaderFields(with: cookies)) { current, _ in current }
        }
        if !has("User-Agent") {
            headers["User-Agent"] = userAgent
        }
        if !has("Accept-Language") {
            headers["Accept-Language"] = acceptLanguage
        }
        if !has("Accept") {
            headers["Accept"] = "*/*"
        }
        return headers
    }

    /// Keeps the cookies set by the response, like the URL loading system does.
    static func storeCookies(of response: HTTPURLResponse, for request: URLRequest) {
        guard request.httpShouldHandleCookies, let url = request.url else { return }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: response.stringHeaders, for: url)
        guard !cookies.isEmpty else { return }
        HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: request.mainDocumentURL)
    }

    /// Same shape as the default user agent of `URLSession`: `App/42 CFNetwork/1568.200.51 Darwin/24.1.0`.
    static let userAgent: String = {
        let bundle = Bundle.main
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String) ?? ProcessInfo.processInfo.processName
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        var agent = "\(name.replacingOccurrences(of: " ", with: "%20"))/\(build)"
        if let network = Bundle(identifier: "com.apple.CFNetwork")?.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            agent += " CFNetwork/\(network)"
        }
        var system = utsname()
        if uname(&system) == 0 {
            let release = withUnsafeBytes(of: &system.release) { bytes in
                String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
            }
            agent += " Darwin/\(release)"
        }
        return agent
    }()

    /// `fr-FR,fr;q=0.9,en;q=0.8`
    static var acceptLanguage: String {
        Locale.preferredLanguages.prefix(5).enumerated().map { index, language in
            index == 0 ? language : "\(language);q=\(String(format: "%.1f", max(0.1, 1.0 - Double(index) * 0.1)))"
        }.joined(separator: ",")
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
