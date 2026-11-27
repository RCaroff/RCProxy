import XCTest
@testable import RCProxy

final class DelegatedRequestTests: XCTestCase {

    func testAddsWhatTheLoadingSystemWouldHaveAdded() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://delegated.example.com/path")))
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")

        let headers = DelegatedRequest.headers(for: request)

        XCTAssertEqual(headers["Authorization"], "Bearer token")
        XCTAssertEqual(headers["Accept"], "*/*")
        XCTAssertFalse(try XCTUnwrap(headers["Accept-Language"]).isEmpty)
        let agent = try XCTUnwrap(headers["User-Agent"])
        XCTAssertTrue(agent.contains("CFNetwork/"), agent)
        XCTAssertTrue(agent.contains("Darwin/"), agent)
    }

    func testKeepsTheHeadersOfTheApp() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://delegated.example.com")))
        request.setValue("MyApp/1.0", forHTTPHeaderField: "user-agent")
        request.setValue("application/json", forHTTPHeaderField: "ACCEPT")
        request.setValue("de", forHTTPHeaderField: "Accept-Language")

        let headers = DelegatedRequest.headers(for: request)

        XCTAssertEqual(headers.count, 3, "\(headers)")
        XCTAssertTrue(headers.values.contains("MyApp/1.0"))
    }

    func testCookiesTravelBothWays() throws {
        let url = try XCTUnwrap(URL(string: "https://cookies-\(UUID().uuidString.lowercased()).example.com/api"))
        let request = URLRequest(url: url)
        defer { HTTPCookieStorage.shared.cookies(for: url)?.forEach(HTTPCookieStorage.shared.deleteCookie) }

        // Set by a response performed elsewhere…
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Set-Cookie": "session=abc123; Path=/", "Content-Type": "application/json"]
        ))
        DelegatedRequest.storeCookies(of: response, for: request)

        // …and sent with the next request.
        XCTAssertEqual(DelegatedRequest.headers(for: request)["Cookie"], "session=abc123")

        var withoutCookies = request
        withoutCookies.httpShouldHandleCookies = false
        XCTAssertNil(DelegatedRequest.headers(for: withoutCookies)["Cookie"])
    }
}
