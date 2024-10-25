//
//  SessionRequestsStorage.swift
//  
//
//  Created by Rémi Caroff on 13/02/2023.
//

import Foundation

final class SessionRequestsStorage: RequestsStorage {
    
    private var requestItems: [RequestItem] = []
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
        return requestItems
    }

    func store(request: RequestData) {
        requestItems.insert(RequestItem(with: request), at: 0)
    }

    func store(responseData: ResponseData, forRequestID id: String) {
        requestItems.first(where: { $0.id == id })?.populate(with: responseData)
    }

    func clear() {
        requestItems = []
    }
}
