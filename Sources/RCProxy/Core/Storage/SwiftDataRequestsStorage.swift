//
//  SwiftDataRequestsStorage.swift
//  RCProxy
//
//  Stores the requests in a SQLite database, using SwiftData.
//

import Foundation
import SwiftData
import RCProxyCore

/// The persisted form of a `RequestItem`.
///
/// Instances never leave `SwiftDataStore`: everything that crosses its boundary is a `RequestItem` value.
@Model
final class StoredRequest {
    @Attribute(.unique) var id: String
    var date: Date
    var url: String
    var method: String
    var cURL: String
    var statusCode: Int
    var requestHeaders: Data?
    var responseHeaders: Data?
    @Attribute(.externalStorage) var requestBodyData: Data?
    @Attribute(.externalStorage) var responseBodyData: Data?
    var duration: Double?
    var errorDescription: String?

    init(_ item: RequestItem) {
        id = item.id
        date = item.date
        url = item.fullURL
        method = item.method
        cURL = item.cURL
        statusCode = item.statusCode
        requestHeaders = try? JSONEncoder().encode(item.requestHeaders)
        responseHeaders = try? JSONEncoder().encode(item.responseHeaders)
        requestBodyData = item.requestBodyData
        responseBodyData = item.responseBodyData
        duration = item.duration
        errorDescription = item.errorDescription
    }

    var item: RequestItem {
        RequestItem(
            id: id,
            date: date,
            fullURL: url,
            method: method,
            requestHeaders: Self.headers(from: requestHeaders),
            requestBodyData: requestBodyData,
            responseHeaders: Self.headers(from: responseHeaders),
            responseBodyData: responseBodyData,
            statusCode: statusCode,
            cURL: cURL,
            duration: duration,
            errorDescription: errorDescription
        )
    }

    func apply(_ completion: RequestCompletion) {
        statusCode = completion.statusCode
        responseHeaders = try? JSONEncoder().encode(completion.headers)
        responseBodyData = completion.body
        duration = completion.duration
        errorDescription = completion.errorDescription
    }

    private static func headers(from data: Data?) -> [String: String] {
        guard let data else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}

/// Owns the `ModelContext`. Being an actor, it serializes every access to the database.
@ModelActor
actor SwiftDataStore {

    func fetch(limit: Int) -> [RequestItem] {
        var descriptor = FetchDescriptor<StoredRequest>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        let stored = (try? modelContext.fetch(descriptor)) ?? []
        return stored.map(\.item)
    }

    func insert(_ item: RequestItem, maxRequestsCount: Int) {
        modelContext.insert(StoredRequest(item))
        trim(to: maxRequestsCount)
        save()
    }

    func complete(id: String, with completion: RequestCompletion) -> RequestItem? {
        var descriptor = FetchDescriptor<StoredRequest>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let stored = try? modelContext.fetch(descriptor).first else { return nil }
        stored.apply(completion)
        let item = stored.item
        save()
        return item
    }

    func clear() {
        let stored = (try? modelContext.fetch(FetchDescriptor<StoredRequest>())) ?? []
        for request in stored {
            modelContext.delete(request)
        }
        save()
    }

    /// Deletes the oldest requests beyond `maxRequestsCount`.
    private func trim(to maxRequestsCount: Int) {
        guard let count = try? modelContext.fetchCount(FetchDescriptor<StoredRequest>()),
              count > maxRequestsCount else { return }
        var descriptor = FetchDescriptor<StoredRequest>(sortBy: [SortDescriptor(\.date, order: .forward)])
        descriptor.fetchLimit = count - maxRequestsCount
        let oldest = (try? modelContext.fetch(descriptor)) ?? []
        for request in oldest {
            modelContext.delete(request)
        }
    }

    private func save() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            // Never let a failed write take the host app down: drop the pending changes.
            modelContext.rollback()
            print("[RCProxy] Could not save requests: \(error)")
        }
    }
}

/// Stores the requests in a SQLite database, using SwiftData.
///
/// The database is opened lazily, off the main thread. If it cannot be opened (corrupted file,
/// incompatible schema, read-only volume…), the storage degrades gracefully: it recreates the file,
/// then falls back to an in-memory database, and finally to a plain in-memory list.
actor SwiftDataRequestsStorage: RequestsStorage {

    enum Location: Sendable {
        /// The default location: a file in the app's container.
        case automatic
        /// Nothing is written on disk. Used by tests, and as a fallback.
        case inMemory
        case file(URL)
    }

    private enum Backend {
        case database(SwiftDataStore)
        case memory(SessionRequestsStorage)
    }

    private let maxRequestsCount: Int
    private let location: Location
    private var backend: Backend?

    init(maxRequestsCount: UInt, location: Location = .automatic) {
        self.maxRequestsCount = RequestsStorageDefaults.normalized(maxRequestsCount)
        self.location = location
    }

    func fetch() async -> [RequestItem] {
        switch resolvedBackend() {
        case .database(let store): return await store.fetch(limit: maxRequestsCount)
        case .memory(let storage): return await storage.fetch()
        }
    }

    func insert(_ item: RequestItem) async {
        switch resolvedBackend() {
        case .database(let store): await store.insert(item, maxRequestsCount: maxRequestsCount)
        case .memory(let storage): await storage.insert(item)
        }
    }

    @discardableResult
    func complete(id: String, with completion: RequestCompletion) async -> RequestItem? {
        switch resolvedBackend() {
        case .database(let store): return await store.complete(id: id, with: completion)
        case .memory(let storage): return await storage.complete(id: id, with: completion)
        }
    }

    func clear() async {
        switch resolvedBackend() {
        case .database(let store): await store.clear()
        case .memory(let storage): await storage.clear()
        }
    }

    // MARK: Setup

    private func resolvedBackend() -> Backend {
        if let backend { return backend }
        let resolved: Backend
        if let container = Self.makeContainer(location: location) {
            resolved = .database(SwiftDataStore(modelContainer: container))
        } else {
            print("[RCProxy] The database is unavailable: requests are kept in memory for this session.")
            resolved = .memory(SessionRequestsStorage(maxRequestsCount: UInt(maxRequestsCount)))
        }
        backend = resolved
        return resolved
    }

    private static func makeContainer(location: Location) -> ModelContainer? {
        let schema = Schema([StoredRequest.self])

        func container(_ configuration: ModelConfiguration) -> ModelContainer? {
            try? ModelContainer(for: schema, configurations: [configuration])
        }

        // CloudKit and app groups are explicitly left out: with the default (automatic) settings,
        // a host app having these entitlements would get its requests log synced or relocated.
        let inMemory = ModelConfiguration(
            "RCProxy",
            schema: schema,
            isStoredInMemoryOnly: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        let storeURL: URL?
        switch location {
        case .inMemory:
            return container(inMemory)
        case .file(let url):
            storeURL = url
        case .automatic:
            removeLegacyCoreDataStore()
            storeURL = defaultStoreURL()
        }

        guard let storeURL else { return container(inMemory) }
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let onDisk = ModelConfiguration("RCProxy", schema: schema, url: storeURL, cloudKitDatabase: .none)
        if let container = container(onDisk) {
            return container
        }

        // The file is unusable (corrupted, or written by an incompatible version). It only holds
        // debugging data: start over with a fresh one.
        removeStore(at: storeURL)
        return container(onDisk) ?? container(inMemory)
    }

    /// tvOS apps may only write in the caches directory.
    private static var baseDirectory: URL? {
        #if os(tvOS)
        let directory = FileManager.SearchPathDirectory.cachesDirectory
        #else
        let directory = FileManager.SearchPathDirectory.applicationSupportDirectory
        #endif
        return FileManager.default.urls(for: directory, in: .userDomainMask).first
    }

    private static func defaultStoreURL() -> URL? {
        baseDirectory?
            .appendingPathComponent("RCProxy", isDirectory: true)
            .appendingPathComponent("Requests.store")
    }

    private static func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
        // Bodies stored outside of the SQLite file.
        let support = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.deletingPathExtension().lastPathComponent)_SUPPORT")
        try? FileManager.default.removeItem(at: support)
    }

    /// RCProxy 3 and earlier used Core Data. Its database is not read anymore: remove it.
    private static func removeLegacyCoreDataStore() {
        guard let baseDirectory else { return }
        removeStore(at: baseDirectory.appendingPathComponent("RCProxy.sqlite"))
    }
}
