import XCTest
@testable import RCProxyCore

final class JSONValueTests: XCTestCase {

    func testKeepsKeysInDocumentOrder() throws {
        let value = try JSONValue(string: #"{"zebra": 1, "alpha": 2, "mango": {"b": true, "a": null}}"#)

        guard case .object(let members) = value else { return XCTFail("Expected an object") }
        XCTAssertEqual(members.map(\.key), ["zebra", "alpha", "mango"])
        guard case .object(let nested) = members[2].value else { return XCTFail("Expected a nested object") }
        XCTAssertEqual(nested.map(\.key), ["b", "a"])
        XCTAssertEqual(nested.map(\.value), [.bool(true), .null])
    }

    func testKeepsNumbersAsWritten() throws {
        let value = try JSONValue(string: "[12, -0.50, 1e9, 9223372036854775808, 1.0E-3, 0]")

        XCTAssertEqual(value, .array([
            .number("12"), .number("-0.50"), .number("1e9"), .number("9223372036854775808"),
            .number("1.0E-3"), .number("0")
        ]))
    }

    func testDecodesEscapes() throws {
        let value = try JSONValue(string: #"["a\"b", "tab\tnewline\n", "slash\/", "back\\slash", "é", "😀", "\ud83d"]"#)

        XCTAssertEqual(value, .array([
            .string("a\"b"), .string("tab\tnewline\n"), .string("slash/"), .string("back\\slash"),
            .string("é"), .string("😀"), .string("\u{FFFD}")
        ]))
    }

    func testAcceptsScalarsWhitespaceAndByteOrderMark() throws {
        XCTAssertEqual(try JSONValue(string: " \r\n\t \"text\" \n"), .string("text"))
        XCTAssertEqual(try JSONValue(string: "true"), .bool(true))
        XCTAssertEqual(try JSONValue(string: "null"), .null)
        XCTAssertEqual(try JSONValue(data: Data([0xEF, 0xBB, 0xBF]) + Data("{}".utf8)), .object([]))
        XCTAssertEqual(try JSONValue(string: "{ }"), .object([]))
        XCTAssertEqual(try JSONValue(string: "[\r\n]"), .array([]))
    }

    func testRejectsMalformedDocuments() {
        let documents = [
            "", " ", "{", "}", "[", "]", "{\"a\"}", "{\"a\":}", "{\"a\":1,}", "[1,]", "[1 2]", "{a:1}",
            "\"unterminated", "\"bad\\", "tru", "nul", "-", "1.", "1e", "1e+", "01x", "{} {}", "[1]]",
            "<html></html>", "{\"a\":1}garbage"
        ]
        for document in documents {
            XCTAssertThrowsError(try JSONValue(string: document), "Should reject: \(document)")
        }
    }

    /// Bodies can be cut anywhere (dropped connection…): no prefix of a document may crash the parser.
    func testEveryPrefixOfADocumentIsHandled() throws {
        let document = #"""
        {"id": 9223372036854775807, "name": "Luke \"Sky\" walker\\", "tags": ["a", "bé", {"deep": [1, -2.5e-3, true, false, null]}],
         "empty": {}, "list": [], "nested": {"k": {"k": {"k": "v"}}}, "text": "line\nbreak"}
        """#
        let bytes = Array(document.utf8)

        for length in 0...bytes.count {
            _ = try? JSONValue(data: Data(bytes[0..<length]))
        }
        XCTAssertNoThrow(try JSONValue(data: Data(bytes)))
    }

    func testArbitraryBytesAreHandled() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let count = Int.random(in: 0...64, using: &generator)
            let bytes = (0..<count).map { _ in UInt8.random(in: 0...255, using: &generator) }
            _ = try? JSONValue(data: Data(bytes))
        }
    }

    func testRefusesDocumentsNestedTooDeeply() {
        let depth = 100_000
        let document = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)

        XCTAssertThrowsError(try JSONValue(string: document))
    }

    func testSerializationRoundTrip() throws {
        let source = #"{"b":[1,2,{"c":"x\ny"}],"a":{},"z":[],"s":"quote\" and \\ tab\t","n":null,"t":true}"#
        let value = try JSONValue(string: source)

        XCTAssertEqual(value.serialized(prettyPrinted: false), source)
        XCTAssertEqual(try JSONValue(string: value.serialized(prettyPrinted: true)), value)
        XCTAssertEqual(
            try JSONValue(string: #"{"a":[1,{"b":null}]}"#).serialized(),
            """
            {
              "a": [
                1,
                {
                  "b": null
                }
              ]
            }
            """
        )
    }

    func testDisplayAndCopyTexts() throws {
        XCTAssertEqual(JSONValue.string("a\"b").displayText, #""a\"b""#)
        XCTAssertEqual(JSONValue.string("a\"b").copyText, "a\"b")
        XCTAssertEqual(JSONValue.number("42").copyText, "42")
        XCTAssertEqual(JSONValue.string("\u{01}").displayText, #""\u0001""#)
        XCTAssertEqual(try JSONValue(string: "[1,2]").childCount, 2)
        XCTAssertTrue(try JSONValue(string: "{}").isContainer)
        XCTAssertFalse(JSONValue.null.isContainer)
    }
}
