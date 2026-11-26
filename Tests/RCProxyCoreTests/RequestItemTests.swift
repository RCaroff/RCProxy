import XCTest
@testable import RCProxyCore

final class RequestItemTests: XCTestCase {

    func testDerivedURLValues() {
        let item = RequestItem(
            fullURL: "https://api.example.com:8443/v1/users/42?page=2&sort=name&page=2",
            method: "GET"
        )

        XCTAssertEqual(item.url, "https://api.example.com:8443/v1/users/42")
        XCTAssertEqual(item.host, "api.example.com")
        XCTAssertEqual(item.relativePath, "/v1/users/42")
        XCTAssertEqual(item.queryParameters.map(\.name), ["page", "sort", "page"])
        XCTAssertEqual(item.queryParameters.map(\.value), ["2", "name", "2"])
        // Repeated parameters must still get distinct identifiers.
        XCTAssertEqual(Set(item.queryParameters.map(\.id)).count, 3)
    }

    func testUnparsableURLIsKeptAsIs() {
        let item = RequestItem(fullURL: "No URL", method: "GET")

        XCTAssertEqual(item.url, "No URL")
        XCTAssertEqual(item.host, "")
        XCTAssertTrue(item.queryParameters.isEmpty)
    }

    func testStatusHelpers() {
        var item = RequestItem(fullURL: "https://example.com", method: "GET")
        XCTAssertFalse(item.isCompleted)
        XCTAssertTrue(item.isError, "A request without response is listed with the errors")
        XCTAssertFalse(item.isSuccess)

        item.statusCode = 204
        XCTAssertTrue(item.isCompleted)
        XCTAssertTrue(item.isSuccess)
        XCTAssertFalse(item.isError)

        item.statusCode = 404
        XCTAssertTrue(item.isError)
        XCTAssertFalse(item.isSuccess)

        item.statusCode = 0
        item.errorDescription = "The request timed out."
        XCTAssertTrue(item.isCompleted)
        XCTAssertTrue(item.isError)
    }

    func testCodableRoundTrip() throws {
        let item = RequestItem(
            id: "abc",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            fullURL: "https://example.com/a?b=c",
            method: "POST",
            requestHeaders: ["Content-Type": "application/json"],
            requestBodyData: Data(#"{"a":1}"#.utf8),
            responseHeaders: ["X-Test": "1"],
            responseBodyData: Data([0x00, 0xFF, 0x10]),
            statusCode: 201,
            cURL: "curl -X POST 'https://example.com/a?b=c'",
            duration: 0.25,
            errorDescription: nil
        )

        let decoded = try JSONDecoder().decode(RequestItem.self, from: JSONEncoder().encode(item))

        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.date, item.date)
        XCTAssertEqual(decoded.fullURL, item.fullURL)
        XCTAssertEqual(decoded.method, item.method)
        XCTAssertEqual(decoded.requestHeaders, item.requestHeaders)
        XCTAssertEqual(decoded.requestBodyData, item.requestBodyData)
        XCTAssertEqual(decoded.responseHeaders, item.responseHeaders)
        XCTAssertEqual(decoded.responseBodyData, item.responseBodyData)
        XCTAssertEqual(decoded.statusCode, item.statusCode)
        XCTAssertEqual(decoded.cURL, item.cURL)
        XCTAssertEqual(decoded.duration, item.duration)
        XCTAssertNil(decoded.errorDescription)
    }

    /// Requests persisted in UserDefaults by RCProxy 3 must still be readable.
    func testDecodesItemsStoredByVersion3() throws {
        let legacy = """
        [{
            "id": "0B2C4A36-0000-4000-8000-000000000001",
            "date": 765432100.5,
            "fullURL": "https://swapi.dev/api/planets?id=42",
            "url": "https://swapi.dev/api/planets",
            "queryParameters": [{"id": "id42", "name": "id", "value": "42"}],
            "method": "GET",
            "requestHeaders": {"x-fake-header": "fake"},
            "responseHeaders": {"Content-Type": "application/json"},
            "statusCode": 200,
            "cURL": "curl -X GET 'https://swapi.dev/api/planets?id=42'",
            "responseBodyData": "e30="
        }]
        """

        let items = try JSONDecoder().decode([RequestItem].self, from: Data(legacy.utf8))

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].url, "https://swapi.dev/api/planets")
        XCTAssertEqual(items[0].statusCode, 200)
        XCTAssertEqual(items[0].responseBodyData, Data("{}".utf8))
        XCTAssertNil(items[0].requestBodyData)
        XCTAssertNil(items[0].duration)
    }
}
