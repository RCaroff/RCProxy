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

    var requestItems: [RequestItem] {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
            return (try? decoder.decode([RequestItem].self, from: data)) ?? []
        }

        set {
            guard let data = try? encoder.encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private let storageKey = "RCProxy_requests_storage_key"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func store(request: RequestData) {
        let item = RequestItem(with: request)
        var items = requestItems
        items.append(item)
        requestItems = items
    }

    func store(responseData: ResponseData, forRequestID id: String) {
        let items = requestItems
        items.first(where: { $0.id == id })?.populate(with: responseData)
        requestItems = items
    }
}
