import XCTest
import RCProxyCore
@testable import RCProxy

/// The same expectations hold for every storage.
final class StorageTests: XCTestCase {

    private var temporaryDirectory: URL!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RCProxyTests-\(UUID().uuidString)", isDirectory: true)
        suiteName = "RCProxyTests-\(UUID().uuidString)"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeItem(_ index: Int, body: Data? = nil) -> RequestItem {
        RequestItem(
            id: "request-\(index)",
            date: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
            fullURL: "https://example.com/items/\(index)?page=\(index)",
            method: "GET",
            requestHeaders: ["X-Index": "\(index)"],
            requestBodyData: body,
            cURL: "curl 'https://example.com/items/\(index)'"
        )
    }

    private func storages(maxRequestsCount: UInt) -> [(name: String, storage: any RequestsStorage)] {
        [
            ("session", SessionRequestsStorage(maxRequestsCount: maxRequestsCount)),
            ("userDefaults", UserDefaultsRequestsStorage(maxRequestsCount: maxRequestsCount, suiteName: suiteName)),
            ("swiftData", SwiftDataRequestsStorage(maxRequestsCount: maxRequestsCount, location: .inMemory)),
            ("swiftData on disk", SwiftDataRequestsStorage(
                maxRequestsCount: maxRequestsCount,
                location: .file(temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/Requests.store"))
            ))
        ]
    }

    func testReturnsMostRecentRequestsFirst() async {
        for (name, storage) in storages(maxRequestsCount: 10) {
            for index in 0..<5 {
                await storage.insert(makeItem(index))
            }

            let items = await storage.fetch()
            XCTAssertEqual(items.map(\.id), ["request-4", "request-3", "request-2", "request-1", "request-0"], name)
            XCTAssertEqual(items.first?.requestHeaders, ["X-Index": "4"], name)
            XCTAssertEqual(items.first?.fullURL, "https://example.com/items/4?page=4", name)
        }
    }

    func testKeepsOnlyTheMostRecentRequests() async {
        for (name, storage) in storages(maxRequestsCount: 3) {
            for index in 0..<10 {
                await storage.insert(makeItem(index))
            }

            let items = await storage.fetch()
            XCTAssertEqual(items.map(\.id), ["request-9", "request-8", "request-7"], name)
        }
    }

    func testCompletingARequestStoresItsResponse() async {
        for (name, storage) in storages(maxRequestsCount: 10) {
            await storage.insert(makeItem(1, body: Data("request body".utf8)))
            await storage.insert(makeItem(2))

            let completion = RequestCompletion(
                statusCode: 201,
                headers: ["Content-Type": "application/json"],
                body: Data(#"{"ok":true}"#.utf8),
                duration: 0.5
            )
            let updated = await storage.complete(id: "request-1", with: completion)
            XCTAssertEqual(updated?.statusCode, 201, name)

            let items = await storage.fetch()
            let stored = items.first { $0.id == "request-1" }
            XCTAssertEqual(stored?.statusCode, 201, name)
            XCTAssertEqual(stored?.responseHeaders, ["Content-Type": "application/json"], name)
            XCTAssertEqual(stored?.responseBodyData, Data(#"{"ok":true}"#.utf8), name)
            XCTAssertEqual(stored?.requestBodyData, Data("request body".utf8), name)
            XCTAssertEqual(stored?.duration, 0.5, name)
            XCTAssertEqual(items.first { $0.id == "request-2" }?.statusCode, 0, name)
        }
    }

    func testCompletingAnUnknownRequestIsHarmless() async {
        for (name, storage) in storages(maxRequestsCount: 10) {
            let updated = await storage.complete(id: "missing", with: RequestCompletion(statusCode: 200))
            XCTAssertNil(updated, name)
            let items = await storage.fetch()
            XCTAssertTrue(items.isEmpty, name)
        }
    }

    func testFailedRequestKeepsItsError() async {
        for (name, storage) in storages(maxRequestsCount: 10) {
            await storage.insert(makeItem(1))
            await storage.complete(id: "request-1", with: RequestCompletion(errorDescription: "The request timed out."))

            let item = await storage.fetch().first
            XCTAssertEqual(item?.statusCode, 0, name)
            XCTAssertEqual(item?.errorDescription, "The request timed out.", name)
        }
    }

    func testClearRemovesEverything() async {
        for (name, storage) in storages(maxRequestsCount: 10) {
            for index in 0..<4 {
                await storage.insert(makeItem(index))
            }
            await storage.clear()

            let items = await storage.fetch()
            XCTAssertTrue(items.isEmpty, name)

            // The storage stays usable.
            await storage.insert(makeItem(42))
            let afterInsert = await storage.fetch()
            XCTAssertEqual(afterInsert.map(\.id), ["request-42"], name)
        }
    }

    func testZeroFallsBackToTheDefaultLimit() async {
        for (name, storage) in storages(maxRequestsCount: 0) {
            for index in 0..<120 {
                await storage.insert(makeItem(index))
            }
            let items = await storage.fetch()
            XCTAssertEqual(items.count, 100, name)
        }
    }

    /// Requests are recorded from many threads at once, while the UI reads and clears.
    func testConcurrentAccessIsSafe() async {
        for (name, storage) in storages(maxRequestsCount: 50) {
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<200 {
                    let item = makeItem(index, body: Data(repeating: 1, count: 2_000))
                    group.addTask {
                        await storage.insert(item)
                        await storage.complete(
                            id: "request-\(index)",
                            with: RequestCompletion(statusCode: 200, body: Data(repeating: 2, count: 2_000))
                        )
                    }
                    if index % 10 == 0 {
                        group.addTask { _ = await storage.fetch() }
                    }
                    if index == 100 {
                        group.addTask { await storage.clear() }
                    }
                }
            }

            let items = await storage.fetch()
            XCTAssertLessThanOrEqual(items.count, 50, name)
            XCTAssertEqual(Set(items.map(\.id)).count, items.count, name)
        }
    }
}
