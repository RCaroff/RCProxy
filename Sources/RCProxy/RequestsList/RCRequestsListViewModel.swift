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
    @Published var isErrorFiltered: Bool = false {
        didSet {
            toggleErrorFilter()
        }
    }
    @Published var isSuccessFiltered: Bool = false {
        didSet {
            toggleSuccessFilter()
        }
    }
    @Published var searchText: String = "" {
        didSet {
            filterSearch()
        }
    }

    private var allItems: [RequestItem] = []
    private var filteredItems: [RequestItem] = []

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
        if isErrorFiltered {
            if isSuccessFiltered {
                isSuccessFiltered = false
            }

            filteredItems = allItems.filter({
                $0.statusCode >= 400 || $0.statusCode == 0
            })

            items = filteredItems
        }

        filterSearch()
    }

    func toggleSuccessFilter() {
        if isSuccessFiltered {
            if isErrorFiltered {
                isErrorFiltered = false
            }

            filteredItems = allItems.filter({
                $0.statusCode < 400 && $0.statusCode != 0
            })

            items = filteredItems
        }

        filterSearch()
    }

    private func filterSearch() {
        if searchText.isEmpty {
            if isErrorFiltered || isSuccessFiltered {
                items = filteredItems
            } else {
                items = allItems
            }

        } else {
            if isErrorFiltered || isSuccessFiltered {
                items = filteredItems.filter {
                    $0.url.localizedStandardContains(searchText)
                }
            } else {
                items = allItems.filter {
                    $0.url.localizedStandardContains(searchText)
                }
            }
        }


    }
}
