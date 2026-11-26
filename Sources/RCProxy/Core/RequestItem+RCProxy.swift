//
//  RequestItem+RCProxy.swift
//  RCProxy
//
//  Created by Rémi Caroff on 03/02/2023.
//

import Foundation
import UIKit
import RCProxyCore

extension RequestItem {

    /// Creates the item of a request that is about to be sent.
    /// - parameter body: The body of the request, already read from its stream.
    init(id: String, urlRequest: URLRequest, body: Data?, date: Date) {
        self.init(
            id: id,
            date: date,
            fullURL: urlRequest.url?.absoluteString ?? "No URL",
            method: (urlRequest.httpMethod ?? "").uppercased(),
            requestHeaders: urlRequest.allHTTPHeaderFields ?? [:],
            requestBodyData: body,
            cURL: urlRequest.cURL(body: body)
        )
    }

    var requestBody: String {
        Self.text(of: requestBodyData)
    }

    var responseBody: String {
        Self.text(of: responseBodyData)
    }

    var requestBodyJson: [String: Any] {
        return requestBodyData.toJSONObject()
    }

    var responseBodyJson: [String: Any] {
        return responseBodyData.toJSONObject()
    }

    var statusColor: UIColor {
        var statusColor: UIColor = statusCode >= 400 ? .systemRed : .systemGreen
        if (300...399) ~= statusCode {
            statusColor = .systemMint
        }
        if statusCode == 0 {
            statusColor = .black
        }
        return statusColor
    }

    var dateString: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .long
        return df.string(from: date)
    }

    /// Pretty-printed JSON when the data is JSON, the raw text otherwise.
    private static func text(of data: Data?) -> String {
        guard let data, !data.isEmpty else {
            return "No content"
        }
        return data.toJSON() ?? String(data: data, encoding: .utf8) ?? "No content"
    }
}

extension [String: String] {
    /// The headers as text, or a placeholder when there is none.
    var headersText: String {
        isEmpty ? "No content" : prettyfiedHeaders()
    }
}
