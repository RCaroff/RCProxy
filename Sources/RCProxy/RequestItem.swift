//
//  RequestItem.swift
//  
//
//  Created by Rémi Caroff on 03/02/2023.
//

import Foundation
import UIKit

class RequestItem: Codable, Identifiable {
    var id: String
    var date: Date
    let url: String
    let method: String
    let requestHeaders: [String: String]
    var responseHeaders: [String: String] = [:]
    var statusCode: Int = 0
    let cURL: String
    let requestBodyData: Data?
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

    init(with requestData: RequestData) {
        id =  requestData.id
        cURL = requestData.urlRequest.cURL()
        url = requestData.urlRequest.url?.absoluteString ?? "No URL"
        method = (requestData.urlRequest.httpMethod ?? "").uppercased()
        requestBodyData = requestData.urlRequest.bodyStream()
        requestHeaders = requestData.urlRequest.allHTTPHeaderFields ?? ["No":"Content"]
        self.date = requestData.date
    }

    func populate(with responseData: ResponseData) {
        responseBodyData = responseData.data
        statusCode = responseData.urlResponse.statusCode
    }
}
