//
//  RCProxyViewModel.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//
import Foundation
import SwiftUI

final class RCRequestsListViewModel: ObservableObject {

    @Published var items: [RequestItem] = []

    private var storage: RequestsStorage

    init(storage: RequestsStorage) {
        self.storage = storage
        fetch()
    }

    func fetch() {
        items = storage.requestItems
    }

    func clear() {
        items = []
        storage.clear()
    }
}
