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
    var url: String
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
        self.id = coreDataModel.id
        self.date = coreDataModel.date
        self.url = coreDataModel.url
        self.method = coreDataModel.method
        self.requestHeaders = (coreDataModel.requestHeaders?.toJSONObject() as? [String: String]) ?? ["No":"Content"]
        self.responseHeaders = (coreDataModel.responseHeaders?.toJSONObject() as? [String: String]) ?? ["No":"Content"]
        self.statusCode = Int(coreDataModel.statusCode)
        self.cURL = coreDataModel.cURL
        self.requestBodyData = coreDataModel.requestBodyData
        self.responseBodyData = coreDataModel.responseBodyData
    }

    init(with requestData: RequestData) {
        id =  requestData.id
        cURL = requestData.urlRequest.cURL()
        url = requestData.urlRequest.url?.absoluteString ?? "No URL"
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
