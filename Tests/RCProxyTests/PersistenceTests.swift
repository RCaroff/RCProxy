import XCTest
import RCProxyCore
@testable import RCProxy

final class PersistenceTests: XCTestCase {

    private var temporaryDirectory: URL!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RCProxyTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        suiteName = "RCProxyTests-\(UUID().uuidString)"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeItem(_ index: Int, bodySize: Int = 0) -> RequestItem {
        RequestItem(
            id: "request-\(index)",
            date: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
            fullURL: "https://example.com/items/\(index)",
            method: "POST",
            requestBodyData: bodySize == 0 ? nil : Data(repeating: 0x61, count: bodySize),
            statusCode: 200
        )
    }

    // MARK: SwiftData

    func testDatabaseSurvivesARelaunch() async {
        let url = temporaryDirectory.appendingPathComponent("Requests.store")

        let first = SwiftDataRequestsStorage(maxRequestsCount: 10, location: .file(url))
        await first.insert(makeItem(1, bodySize: 200_000))
        await first.insert(makeItem(2))

        let second = SwiftDataRequestsStorage(maxRequestsCount: 10, location: .file(url))
        let items = await second.fetch()

        XCTAssertEqual(items.map(\.id), ["request-2", "request-1"])
        XCTAssertEqual(items.last?.requestBodyData?.count, 200_000)
    }

    func testDatabaseRecoversFromACorruptedFile() async throws {
        let url = temporaryDirectory.appendingPathComponent("Requests.store")
        try Data("this is definitely not a SQLite database".utf8).write(to: url)

        let storage = SwiftDataRequestsStorage(maxRequestsCount: 10, location: .file(url))
        await storage.insert(makeItem(1))

        let items = await storage.fetch()
        XCTAssertEqual(items.map(\.id), ["request-1"])
    }

    func testDatabaseFallsBackToMemoryWhenTheLocationIsUnusable() async {
        // A path below a regular file can never be created.
        let file = temporaryDirectory.appendingPathComponent("not-a-directory")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        let url = file.appendingPathComponent("nested/Requests.store")

        let storage = SwiftDataRequestsStorage(maxRequestsCount: 10, location: .file(url))
        await storage.insert(makeItem(1))
        await storage.complete(id: "request-1", with: RequestCompletion(statusCode: 204))

        let items = await storage.fetch()
        XCTAssertEqual(items.map(\.statusCode), [204])
    }

    func testInsertingTheSameRequestTwiceKeepsOneCopy() async {
        let storage = SwiftDataRequestsStorage(maxRequestsCount: 10, location: .inMemory)
        await storage.insert(makeItem(1))
        await storage.insert(makeItem(1))

        let items = await storage.fetch()
        XCTAssertEqual(items.count, 1)
    }

    // MARK: UserDefaults

    func testUserDefaultsSurviveARelaunch() async {
        let first = UserDefaultsRequestsStorage(maxRequestsCount: 10, suiteName: suiteName)
        await first.insert(makeItem(1))
        await first.insert(makeItem(2, bodySize: 1_000))
        await first.flush()

        let second = UserDefaultsRequestsStorage(maxRequestsCount: 10, suiteName: suiteName)
        let items = await second.fetch()

        XCTAssertEqual(items.map(\.id), ["request-2", "request-1"])
        XCTAssertEqual(items.first?.requestBodyData?.count, 1_000)
    }

    func testUserDefaultsStayUnderTheirByteBudget() async throws {
        let budget = 50_000
        let storage = UserDefaultsRequestsStorage(maxRequestsCount: 100, byteBudget: budget, suiteName: suiteName)
        for index in 0..<30 {
            await storage.insert(makeItem(index, bodySize: 10_000))
        }
        await storage.flush()

        let persisted = try XCTUnwrap(UserDefaults(suiteName: suiteName)?.data(forKey: "RCProxy_requests_storage_key"))
        XCTAssertLessThanOrEqual(persisted.count, budget)

        let reloaded = await UserDefaultsRequestsStorage(maxRequestsCount: 100, suiteName: suiteName).fetch()
        XCTAssertFalse(reloaded.isEmpty)
        XCTAssertEqual(reloaded.first?.id, "request-29", "The most recent requests are the ones worth keeping")

        // The running session still sees everything.
        let live = await storage.fetch()
        XCTAssertEqual(live.count, 30)
    }

    func testOversizedRequestIsPersistedWithoutItsBodies() async throws {
        let storage = UserDefaultsRequestsStorage(maxRequestsCount: 10, byteBudget: 20_000, suiteName: suiteName)
        await storage.insert(makeItem(1, bodySize: 500_000))
        await storage.flush()

        let reloaded = await UserDefaultsRequestsStorage(maxRequestsCount: 10, suiteName: suiteName).fetch()
        XCTAssertEqual(reloaded.map(\.id), ["request-1"])
        XCTAssertNil(reloaded.first?.requestBodyData)
    }
}
