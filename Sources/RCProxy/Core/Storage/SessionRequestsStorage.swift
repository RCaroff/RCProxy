//
//  SessionRequestsStorage.swift
//  
//
//  Created by Rémi Caroff on 13/02/2023.
//

import Foundation

final class SessionRequestsStorage: RequestsStorage {
    var requestItems: [RequestItem] = []

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
