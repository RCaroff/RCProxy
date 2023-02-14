//
//  UserDefaultsRequestsStorage.swift
//  
//
//  Created by Rémi Caroff on 13/02/2023.
//

import Foundation

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

    func clear() {
        requestItems = []
    }
}
