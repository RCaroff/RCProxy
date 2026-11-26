//
//  UserDefaultsRequestsStorage.swift
//
//
//  Created by Rémi Caroff on 13/02/2023.
//

import Foundation
import RCProxyCore

/// Keeps the requests in `UserDefaults.standard`, so that they survive app relaunches.
///
/// `UserDefaults` is not made for large amounts of data: tvOS terminates an app whose defaults
/// exceed 1 MB. The persisted copy is therefore kept under a byte budget, dropping the oldest
/// requests (and, as a last resort, the bodies) when needed.
actor UserDefaultsRequestsStorage: RequestsStorage {

    private let storageKey = "RCProxy_requests_storage_key"
    private let maxRequestsCount: Int
    private let byteBudget: Int
    private let defaults: UserDefaults

    /// In-memory copy, most recent first. Loaded lazily from the defaults.
    private var cache: [RequestItem]?
    private var pendingSave: Task<Void, Never>?

    init(maxRequestsCount: UInt, byteBudget: Int? = nil, suiteName: String? = nil) {
        self.maxRequestsCount = RequestsStorageDefaults.normalized(maxRequestsCount)
        #if os(tvOS)
        self.byteBudget = byteBudget ?? 256 * 1024
        #else
        self.byteBudget = byteBudget ?? 3 * 1024 * 1024
        #endif
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    func fetch() async -> [RequestItem] {
        loadIfNeeded()
    }

    func insert(_ item: RequestItem) async {
        var items = loadIfNeeded()
        items.insert(item, at: 0)
        if items.count > maxRequestsCount {
            items.removeLast(items.count - maxRequestsCount)
        }
        cache = items
        scheduleSave()
    }

    @discardableResult
    func complete(id: String, with completion: RequestCompletion) async -> RequestItem? {
        var items = loadIfNeeded()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        completion.apply(to: &items[index])
        cache = items
        scheduleSave()
        return items[index]
    }

    func clear() async {
        cache = []
        pendingSave?.cancel()
        pendingSave = nil
        defaults.removeObject(forKey: storageKey)
    }

    /// Writes the pending changes right away. Mostly useful for tests.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        save()
    }

    // MARK: Private

    private func loadIfNeeded() -> [RequestItem] {
        if let cache { return cache }
        var items: [RequestItem] = []
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([RequestItem].self, from: data) {
            items = decoded.sorted { $0.date > $1.date }
        }
        if items.count > maxRequestsCount {
            items.removeLast(items.count - maxRequestsCount)
        }
        cache = items
        return items
    }

    /// Requests come in bursts: saving once things settle avoids re-encoding everything for each of them.
    private func scheduleSave() {
        guard pendingSave == nil else { return }
        pendingSave = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.saveScheduled()
        }
    }

    private func saveScheduled() {
        pendingSave = nil
        save()
    }

    private func save() {
        guard let cache else { return }
        guard let data = Self.encode(cache, budget: byteBudget) else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    /// Encodes as many of the most recent requests as the budget allows.
    /// A request that is too big on its own is kept without its bodies.
    static func encode(_ items: [RequestItem], budget: Int) -> Data? {
        let encoder = JSONEncoder()
        var output = Data("[".utf8)
        var isEmpty = true

        for item in items {
            guard var encoded = try? encoder.encode(item) else { continue }
            let separator = isEmpty ? 0 : 1
            if output.count + separator + encoded.count + 1 > budget {
                var stripped = item
                stripped.requestBodyData = nil
                stripped.responseBodyData = nil
                guard let smaller = try? encoder.encode(stripped),
                      output.count + separator + smaller.count + 1 <= budget else { break }
                encoded = smaller
            }
            if !isEmpty {
                output.append(UInt8(ascii: ","))
            }
            output.append(encoded)
            isEmpty = false
        }

        output.append(UInt8(ascii: "]"))
        return isEmpty ? nil : output
    }
}
