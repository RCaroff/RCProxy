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
            processErrorFiltering()
        }
    }
    @Published var isSuccessFiltered: Bool = false {
        didSet {
            processSuccessFiltering()
        }
    }
    @Published var searchText: String = "" {
        didSet {
            processSearchFiltering()
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
            allItems = await storage.fetch()

            if isErrorFiltered {
                processErrorFiltering()
                return
            }

            if isSuccessFiltered {
                processSuccessFiltering()
                return
            }

            processSearchFiltering()
        }
    }

    func clear() {
        storage.clear()
        items = []
        allItems = []
        filteredItems = []
    }

    private func processErrorFiltering() {
        if isErrorFiltered {
            if isSuccessFiltered {
                isSuccessFiltered = false
            }

            filteredItems = allItems.filter({
                $0.statusCode >= 400 || $0.statusCode == 0
            })

            items = filteredItems
        }

        processSearchFiltering()
    }

    private func processSuccessFiltering() {
        if isSuccessFiltered {
            if isErrorFiltered {
                isErrorFiltered = false
            }

            filteredItems = allItems.filter({
                $0.statusCode < 400 && $0.statusCode != 0
            })

            items = filteredItems
        }

        processSearchFiltering()
    }

    private func processSearchFiltering() {
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
