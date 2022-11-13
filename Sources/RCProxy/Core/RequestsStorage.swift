//
//  RequestsStorage.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation

typealias RequestData = (urlRequest: URLRequest, date: Date)
typealias ResponseData = (urlResponse: URLResponse, data: Data?)

protocol RequestsStorage {
    var requests: [RequestData] { get }
    var responses: [URLRequest: ResponseData] { get }
    func store(request: RequestData)
    func store(responseData: ResponseData, for urlRequest: URLRequest)
}

final class SessionRequestsStorage: RequestsStorage {

    var requests: [RequestData] = []
    var responses: [URLRequest: ResponseData] = [:]

    func store(request: RequestData) {
        requests.append(request)
        requests.sort(by: { $0.date > $1.date })
    }

    func store(responseData: ResponseData, for urlRequest: URLRequest) {
        responses.updateValue(responseData, forKey: urlRequest)
    }
}
