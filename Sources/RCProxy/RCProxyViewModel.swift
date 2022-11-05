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
    let requestHeaders: String
    let requestBody: String
    let responseHeaders: String
    let responseBody: String
    var responseBodyJson: [String: Any]
    let statusCode: String
    let statusColor: UIColor

    var responseBodyLines: [JSONLine] {
        responseBody.components(separatedBy: "\n").enumerated().map { (index, element) in
            JSONLine(id: UUID(), blockId: UUID().uuidString, value: element, indentLevel: 0, isExpandable: true)
        }
    }
}

class JSONLine: ObservableObject, Identifiable {
    let id: UUID
    let blockId: String
    let parentBlockId: String?
    let value: String
    let collapsedValue: String
    let indentLevel: Int
    let isExpandable: Bool
    @Published var isExpanded: Bool = false

    internal init(id: UUID, blockId: String, parentBlockId: String? = nil, value: String, indentLevel: Int, isExpandable: Bool) {
        self.id = id
        self.blockId = blockId
        self.parentBlockId = parentBlockId
        self.value = value
        self.indentLevel = indentLevel
        self.collapsedValue = "{ ... }"
        self.isExpandable = isExpandable
    }
}

final class RCProxyViewModel: ObservableObject {

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
            let requestHeaders = map(headers: (request.allHTTPHeaderFields ?? [:]))
                .description
                .replacingOccurrences(of: ", ", with: "\n")
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
            let requestBody = request.httpBody.toJSON()
            let response = storage.responses[request]?.0 as? HTTPURLResponse
            let responseData = storage.responses[request]?.1
            let responseHeaders = response?.allHeaderFields
                .description
                .replacingOccurrences(of: ", ", with: "\n")
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
            let responseBody = responseData?.toJSON() ?? "No content"
            let responseBodyJson =  responseData?.toJSONObject() ?? [:]
            let statusCode = response?.statusCode ?? 0
            let statusColor: UIColor = statusCode >= 400 ? .systemRed : .systemGreen

            let item = RequestItem(
                url: urlString,
                requestHeaders: requestHeaders,
                requestBody: requestBody,
                responseHeaders: responseHeaders ?? "No Content",
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
