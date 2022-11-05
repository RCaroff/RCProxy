//
//  RequestsStorage.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation

typealias RequestData = (urlRequest: URLRequest, date: Date)

protocol RequestsStorage {
    var requests: [RequestData] { get }
    var responses: [URLRequest: (URLResponse, Data?)] { get }
    func store(request: RequestData)
    func store(response: URLResponse, data: Data?, for urlRequest: URLRequest)
}

final class SessionRequestsStorage: RequestsStorage {

    var requests: [RequestData] = []
    var responses: [URLRequest: (URLResponse, Data?)] = [:]

    func store(request: RequestData) {
        requests.append(request)
        requests.sort(by: { $0.date > $1.date })
    }

    func store(response: URLResponse, data: Data?, for urlRequest: URLRequest) {
        responses.updateValue((response, data), forKey: urlRequest)
    }
}
