//
//  RCProxyViewModel.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//
import Foundation
import SwiftUI

final class RCRequestsListViewModel: ObservableObject {

    var storage: RequestsStorage

    @Published var items: [RequestItem] = []

    init(storage: RequestsStorage) {
        self.storage = storage
        fetch()
    }

    func fetch() {
        items = storage.requestItems
    }
}
