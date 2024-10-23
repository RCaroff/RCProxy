//
//  CoreDataStorage.swift
//  
//
//  Created by Rémi Caroff on 13/02/2023.
//

import Foundation
import CoreData

final class PersistentContainer: NSPersistentContainer {}

final class CoreDataRequestsStorage: RequestsStorage {

    private let queue = DispatchQueue(label: "RCProxy_core_data_storage", qos: .utility)

    private lazy var container: NSPersistentContainer = {
        guard let modelURL = Bundle(for: RCProxy.self).url(forResource: "RCProxy",
                                               withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create model from file: \(modelURL)")
        }

        return NSPersistentContainer(name: "RCProxy", managedObjectModel: mom)
    }()

    private lazy var context: NSManagedObjectContext = {
        return container.newBackgroundContext()
    }()

    private var maxRequestsCount: UInt = 100

    init(maxRequestsCount: UInt) {
        if maxRequestsCount != 0 {
            self.maxRequestsCount = maxRequestsCount
        }
        container.loadPersistentStores { store, error in
            if let error {
                print("Failed loading persistent store: \(error)")
            }
        }
    }

    func store(request: RequestData) {
        queue.async { [weak self, context] in
            guard let cdItem = NSEntityDescription.insertNewObject(forEntityName: "RequestItemCD", into: context) as? RequestItemCD else { return }
            let item = RequestItem(with: request)
            cdItem.id = item.id
            cdItem.date = item.date
            cdItem.url = item.url
            cdItem.method = item.method
            cdItem.requestHeaders = (item.requestHeaders as [String: Any]).toData()
            cdItem.requestBodyData = item.requestBodyData
            cdItem.cURL = item.cURL
            self?.saveContext()
        }
    }

    func store(responseData: ResponseData, forRequestID id: String) {
        queue.async { [weak self, context] in
            let request = RequestItemCD.fetchRequest()
            request.predicate = NSPredicate(format: "id LIKE %@", id)
            guard let itemCD = try? context.fetch(request).first else { return }
            let responseHeaders = responseData.urlResponse.allHeaderFields as? [String: Any] ?? ["No": "Content"]
            itemCD.responseHeaders = responseHeaders.toData()
            itemCD.responseBodyData = responseData.data
            itemCD.statusCode = Int16(responseData.urlResponse.statusCode)
            self?.saveContext()
        }
    }

    func clear() {
        queue.async { [weak self, context] in
            let request = RequestItemCD.fetchRequest()
            if let entities = try? context.fetch(request) {
                entities.forEach { context.delete($0) }
            }
            self?.saveContext()
        }
    }

    func fetch() async -> [RequestItem] {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self else { return }
            let request = RequestItemCD.fetchRequest()
            queue.async {
                guard let requests = try? self.context.fetch(request) else {
                    continuation.resume(returning: [])
                    return
                }
                var sorted = requests
                    .sorted { item1, item2 in
                        return item1.date > item2.date
                    }

                if sorted.count > self.maxRequestsCount {
                    let diff = sorted.count - Int(self.maxRequestsCount)
                    sorted.enumerated().forEach { idx, item in
                        if idx > self.maxRequestsCount {
                            self.context.delete(item)
                        }
                    }
                    sorted.removeLast(diff)
                    self.saveContext()
                }
                let mapped = sorted.map { RequestItem(with: $0) }
                continuation.resume(returning: mapped)
            }
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch let error as NSError {
            print("Error: \(error), \(error.userInfo)")
        }
    }
}

