//
//  UserDefaultsRequestsStorage.swift
//  
//
//  Created by Rémi Caroff on 13/02/2023.
//

import Foundation

final class UserDefaultsRequestsStorage: RequestsStorage {

    private var requestItems: [RequestItem] {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
            let requests = (try? decoder.decode([RequestItem].self, from: data)) ?? []
            return requests.sorted { item1, item2 in
                return item1.date > item2.date
            }
        }

        set {
            guard let data = try? encoder.encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private let storageKey = "RCProxy_requests_storage_key"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let maxRequestsCount: UInt

    init(maxRequestsCount: UInt) {
        self.maxRequestsCount = maxRequestsCount
    }

    func fetch() async -> [RequestItem] {
        var items = requestItems
        if items.count > maxRequestsCount {
            let diff = items.count - Int(maxRequestsCount)
            items.removeLast(diff)
            requestItems = items
        }

        return items
    }

    func store(request: RequestData) {
        let item = RequestItem(with: request)
        var items = requestItems
        items.insert(item, at: 0)
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
