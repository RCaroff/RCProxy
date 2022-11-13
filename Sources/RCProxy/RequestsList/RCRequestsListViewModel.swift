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
    let requestHeaders: [String: Any]
    let requestBody: String
    var requestBodyJson: [String: Any]
    let responseHeaders: [String: Any]
    let responseBody: String
    var responseBodyJson: [String: Any]
    let statusCode: String
    let statusColor: UIColor
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
            let urlString = request.url?.absoluteString ?? "No URL"
            let requestBody = request.httpBody.toJSON()
            let requestBodyJson =  request.httpBody.toJSONObject()
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
                requestHeaders: request.allHTTPHeaderFields ?? ["No":"Content"],
                requestBody: requestBody,
                requestBodyJson: requestBodyJson,
                responseHeaders: (response?.allHeaderFields as? [String: Any]) ?? ["No":"Content"],
                responseBody: responseBody,
                responseBodyJson: responseBodyJson,
                statusCode: "\(statusCode)",
                statusColor: statusColor
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

extension Optional where Wrapped == Data {
    func toJSON() -> String {
        switch self {
        case .none:
            return "No content"
        case .some(let data):
            return data.toJSON()
        }
    }

    func toJSONObject() -> [String: Any] {
        switch self {
        case .none:
            return [:]
        case .some(let data):
            return data.toJSONObject()
        }
    }
}

extension Data {
    func toJSON() -> String {
        do {
            let jsonObject: AnyObject = try JSONSerialization.jsonObject(with: self) as AnyObject
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "No content"
        } catch {
            return "No content"
        }
    }

    func toJSONObject() -> [String: Any] {
        do {
            let jsonObject: Dictionary<String, Any>? = try JSONSerialization.jsonObject(with: self) as? Dictionary<String, Any>
            return jsonObject ?? [:]
        } catch {
            return [:]
        }
    }
}
