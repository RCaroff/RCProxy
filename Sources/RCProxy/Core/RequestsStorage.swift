//
//  RequestsStorage.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation

struct RequestData: Hashable {
    let id: String
    let urlRequest: URLRequest
    let date: Date
}

struct ResponseData: Hashable {
    let urlResponse: HTTPURLResponse
    let data: Data?
}

protocol RequestsStorage {
    var requestItems: [RequestItem] { get set }
    func store(request: RequestData)
    func store(responseData: ResponseData, forRequestID id: String)
}

final class SessionRequestsStorage: RequestsStorage {
    var requestItems: [RequestItem] = []

    func store(request: RequestData) {
        requestItems.append(RequestItem(with: request))
    }

    func store(responseData: ResponseData, forRequestID id: String) {
        requestItems.first(where: { $0.id == id })?.populate(with: responseData)
    }
}

final class UserDefaultsRequestsStorage: RequestsStorage {
    var requestItems: [RequestItem] = []

    let requestsKey = "RCProxy_requests_storage_key"
    let responsesKey = "RCProxy_responses_storage_key"

    func store(request: RequestData) {
        requestItems.append(RequestItem(with: request))
    }

    func store(responseData: ResponseData, forRequestID id: String) {
        requestItems.first(where: { $0.id == id })?.populate(with: responseData)
    }
}
