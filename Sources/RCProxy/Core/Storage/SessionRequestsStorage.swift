//
//  SessionRequestsStorage.swift
//
//
//  Created by Rémi Caroff on 13/02/2023.
//

import Foundation
import RCProxyCore

/// Keeps the requests in memory, until the app is terminated.
actor SessionRequestsStorage: RequestsStorage {

    private var items: [RequestItem] = []
    private let maxRequestsCount: Int

    init(maxRequestsCount: UInt) {
        self.maxRequestsCount = RequestsStorageDefaults.normalized(maxRequestsCount)
    }

    func fetch() async -> [RequestItem] {
        items
    }

    func insert(_ item: RequestItem) async {
        items.insert(item, at: 0)
        if items.count > maxRequestsCount {
            items.removeLast(items.count - maxRequestsCount)
        }
    }

    @discardableResult
    func complete(id: String, with completion: RequestCompletion) async -> RequestItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        completion.apply(to: &items[index])
        return items[index]
    }

    func clear() async {
        items.removeAll()
    }
}
