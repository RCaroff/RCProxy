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
    @Published var isErrorFiltered: Bool = false
    @Published var isSuccessFiltered: Bool = false
    @Published var search: String = "" {
        didSet {
            filterSearch()
        }
    }

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

    func toggleErrorFilter() {
        isErrorFiltered.toggle()
        if isErrorFiltered {
            if isSuccessFiltered {
                toggleSuccessFilter()
            }

            items = allItems.filter({
                $0.statusCode >= 400 || $0.statusCode == 0
            })
        } else {
            items = allItems
        }
    }

    func toggleSuccessFilter() {
        isSuccessFiltered.toggle()
        if isSuccessFiltered {
            if isErrorFiltered {
                toggleErrorFilter()
            }

            items = allItems.filter({
                $0.statusCode < 400 && $0.statusCode != 0
            })

        } else {
            items = allItems
        }
    }

    func clearSearch() {
        search = ""
    }

    private func filterSearch() {
        if isErrorFiltered {
            toggleErrorFilter()
        }

        if isSuccessFiltered {
            toggleSuccessFilter()
        }

        if search.count == 0 {
            items = allItems
            return
        }

        items = allItems.filter {
            $0.url.localizedStandardContains(search)
        }
    }
}
