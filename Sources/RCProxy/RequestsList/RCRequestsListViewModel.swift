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
    @Published var isFiltered: Bool = false

    private var allItems: [RequestItem] = []

    private var storage: RequestsStorage

    init(storage: RequestsStorage) {
        self.storage = storage
        fetch()
    }

    func fetch() {
        Task { @MainActor in
            items = await storage.fetch()
            allItems = items
        }
    }

    func clear() {
        items = []
        storage.clear()
    }

    func toggleErrorFiltering() {
        isFiltered.toggle()
        if isFiltered {
            items = allItems.filter({
                $0.statusCode >= 400
            })
        } else {
            items = allItems
        }
    }
}
