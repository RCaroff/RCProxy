//
//  RequestsStorage.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation

struct RequestData: Hashable {
    let urlRequest: URLRequest
    let date: Date

    func toData() -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
    }
}

struct ResponseData: Hashable {
    let urlResponse: URLResponse
    let data: Data?

    func toData() -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
    }
}

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

final class UserDefaultsRequestsStorage: RequestsStorage {
    let requestsKey = "RCProxy_requests_storage_key"
    let responsesKey = "RCProxy_responses_storage_key"

    var requests: [RequestData] {
        get {

        }

        set {

        }
    }

    var responses: [URLRequest: ResponseData] {
        get {
            (UserDefaults.standard.dictionary(forKey: responsesKey) as? [URLRequest: ResponseData]) ?? [:]
        }

        set {
            UserDefaults.standard.set(newValue, forKey: responsesKey)
        }
    }

    func store(request: RequestData) {
        requests.append(request)
        requests.sort(by: { $0.date > $1.date })
    }

    func store(responseData: ResponseData, for urlRequest: URLRequest) {
        responses.updateValue(responseData, forKey: urlRequest)
    }
}
