import XCTest
@testable import RCProxy

/// Response bodies are arbitrary bytes: whatever comes in, parsing must fail gracefully.
final class JSONParserRobustnessTests: XCTestCase {

    func testEveryPrefixOfADocumentIsHandled() {
        let document = #"""
        {"id": 12, "big": 9223372036854775807, "name": "Luke \"Sky\" walker\\", "ratio": -2.5e-3,
         "tags": ["a", "b", {"deep": [1, 2.0, true, false, null]}], "empty": {}, "list": [], "exp": 1e+2}
        """#

        for length in 0...document.count {
            let prefix = String(document.prefix(length))
            _ = try? JSON.parse(string: prefix)
            _ = Data(prefix.utf8).toJSON()
            _ = Data(prefix.utf8).toJSONObject()
        }
        XCTAssertNoThrow(try JSON.parse(string: document))
    }

    func testTruncatedDocumentsThatUsedToCrash() {
        let documents = [
            #"{"a":1"#,          // missing closing brace
            #"{"a": "#,          // value missing
            "[1, ",              // element missing
            #"["abc\"#,          // ends with a backslash
            "[1e+",              // exponent missing
            "[-",                // lonely minus sign
            "[12",               // number at the very end
            "[1.",               // fraction missing
            #"{"a":{"b":["#
        ]
        for document in documents {
            _ = try? JSON.parse(string: document)
            XCTAssertTrue(Data(document.utf8).toJSONObject().isEmpty, document)
        }
    }

    func testHugeNumbersDoNotTrap() throws {
        let document = "[9223372036854775807, 9223372036854775808, -9223372036854775809, 1e30, -1e30, 1e400, 12, -3]"

        let parsed = try JSON.parse(string: document)

        XCTAssertEqual(parsed[6] as? Int, 12)
        XCTAssertEqual(parsed[7] as? Int, -3)
        XCTAssertNotNil(parsed[3] as? Double)
    }

    func testEscapedBackslashBeforeClosingQuote() throws {
        let parsed = try JSON.parse(string: #"{"path": "C:\\", "next": "value"}"#)

        XCTAssertEqual(parsed["path"] as? String, #"C:\\"#)
        XCTAssertEqual(parsed["next"] as? String, "value")
    }

    func testWindowsLineEndings() throws {
        let parsed = try JSON.parse(string: "{\r\n  \"a\": 1,\r\n  \"b\": [\r\n    true\r\n  ]\r\n}\r\n")

        XCTAssertEqual(parsed["a"] as? Int, 1)
        XCTAssertNotNil(parsed["b"])
    }

    func testDeeplyNestedDocumentIsRefused() {
        let depth = 50_000
        let document = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)

        XCTAssertThrowsError(try JSON.parse(string: document))
    }

    func testNonJSONBodies() {
        XCTAssertNil(Data("<html><body>502 Bad Gateway</body></html>".utf8).toJSON())
        XCTAssertNil(Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00]).toJSON())
        XCTAssertNil(Data().toJSON())
        XCTAssertTrue(Data("plain text".utf8).toJSONObject().isEmpty)
    }
}
