//
//  RequestItem.swift
//  
//
//  Created by Rémi Caroff on 03/02/2023.
//

import Foundation
import UIKit

struct QueryParameterItem: Codable, Identifiable {
    var id: String
    var name: String
    var value: String
}

class RequestItem: Codable, Identifiable {
    var id: String
    var date: Date
    var fullURL: String
    var url: String
    var queryParameters: [QueryParameterItem] = []
    var method: String
    var requestHeaders: [String: String]
    var responseHeaders: [String: String] = [:]
    var statusCode: Int = 0
    var cURL: String
    var requestBodyData: Data?
    var responseBodyData: Data?

    var requestBody: String {
        requestBodyData?.toJSON() ?? "No Content"
    }

    var responseBody: String {
        responseBodyData?.toJSON() ?? "No content"
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

    var relativePath: String {
        URL(string: url)?.relativePath ?? ""
    }

    var dateString: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .long
        return df.string(from: date)
    }

    init(with coreDataModel: RequestItemCD) {
        id = coreDataModel.id
        date = coreDataModel.date
        fullURL = coreDataModel.url
        url = fullURL
        if let urlComps = URLComponents(string: coreDataModel.url) {
            url = "\(urlComps.scheme ?? "")://\(urlComps.host ?? "")\(urlComps.path)"
        }

        if let parsedURL = URLComponents(string: coreDataModel.url) {
            self.queryParameters = parsedURL.queryItems?.compactMap {
                QueryParameterItem(id: "\($0.name)\($0.value ?? "")", name: $0.name, value: $0.value ?? "")
            } ?? []
        }
        method = coreDataModel.method
        requestHeaders = (coreDataModel.requestHeaders?.toJSONObject() as? [String: String]) ?? ["No":"Content"]
        responseHeaders = (coreDataModel.responseHeaders?.toJSONObject() as? [String: String]) ?? ["No":"Content"]
        statusCode = Int(coreDataModel.statusCode)
        cURL = coreDataModel.cURL
        requestBodyData = coreDataModel.requestBodyData
        responseBodyData = coreDataModel.responseBodyData
    }

    init(with requestData: RequestData) {
        id =  requestData.id
        cURL = requestData.urlRequest.cURL()
        fullURL = requestData.urlRequest.url?.absoluteString ?? "No URL"
        url = fullURL
        if let urlComps = URLComponents(string: fullURL) {
            url = "\(urlComps.scheme ?? "")://\(urlComps.host ?? "")\(urlComps.path)"
        }

        if let parsedURL = URLComponents(string: fullURL) {
            queryParameters = parsedURL.queryItems?.compactMap {
                QueryParameterItem(id: "\($0.name)\($0.value ?? "")", name: $0.name, value: $0.value ?? "")
            } ?? []
        }
        method = (requestData.urlRequest.httpMethod ?? "").uppercased()
        requestBodyData = requestData.urlRequest.bodyStream()
        requestHeaders = requestData.urlRequest.allHTTPHeaderFields ?? ["No":"Content"]
        date = requestData.date
    }

    func populate(with responseData: ResponseData) {
        responseBodyData = responseData.data
        responseHeaders = responseData.urlResponse.allHeaderFields as? [String: String] ?? ["No":"Content"]
        statusCode = responseData.urlResponse.statusCode
    }
}
