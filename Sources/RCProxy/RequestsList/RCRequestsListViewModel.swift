//
//  RCProxyViewModel.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//
import Foundation
import SwiftUI

struct RequestItem: Identifiable {
    let id = UUID()
    let url: String
    let method: String
    let requestHeaders: [String: String]
    let requestBody: String
    var requestBodyJson: [String: Any]
    let responseHeaders: [String: String]
    let responseBody: String
    var responseBodyJson: [String: Any]
    let statusCode: String
    let statusColor: UIColor
    let cURL: String

    var relativePath: String {
        URL(string: url)?.relativePath ?? ""
    }
}

final class RCRequestsListViewModel: ObservableObject {

    var storage: RequestsStorage

    @Published var items: [RequestItem] = []

    init(storage: RequestsStorage) {
        self.storage = storage
        fetch()
    }

    func fetch() {
        items = []
        storage.requests.forEach({ request, date in
            let cURL = request.cURL()
            let urlString = request.url?.absoluteString ?? "No URL"
            let method = (request.httpMethod ?? "").uppercased()
            let requestBodyJson =  request.bodySteamAsJSON() as? [String: Any]
            let requestBody = requestBodyJson?.toData()?.toJSON()
            let response = storage.responses[request]?.0 as? HTTPURLResponse
            let responseData = storage.responses[request]?.1
            let responseBody = responseData?.toJSON() ?? "No content"
            let responseBodyJson =  responseData?.toJSONObject() ?? [:]
            let statusCode = response?.statusCode ?? 0
            var statusColor: UIColor = statusCode >= 400 ? .systemRed : .systemGreen
            if (300...399) ~= statusCode {
                statusColor = .systemMint
            }
            if statusCode == 0 {
                statusColor = .black
            }

            let item = RequestItem(
                url: urlString,
                method: method,
                requestHeaders: request.allHTTPHeaderFields ?? ["No":"Content"],
                requestBody: requestBody ?? "No Content",
                requestBodyJson: requestBodyJson ?? [:],
                responseHeaders: (response?.allHeaderFields as? [String: String]) ?? ["No":"Content"],
                responseBody: responseBody,
                responseBodyJson: responseBodyJson,
                statusCode: "\(statusCode)",
                statusColor: statusColor,
                cURL: cURL
            )

            items.append(item)
        })
    }

    func map(headers: [AnyHashable: Any]) -> [String: String] {
        return Dictionary(uniqueKeysWithValues: headers.map({ key, value in
            ("\(key)", "\(value)")
        }))
    }
}
