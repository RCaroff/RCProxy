//
//  JSONValue.swift
//  RCProxyCore
//
//  A small JSON model that keeps the keys in the order they were written,
//  and never crashes on malformed input.
//

import Foundation

/// A key/value pair of a JSON object.
public struct JSONMember: Sendable, Equatable {
    public let key: String
    public let value: JSONValue

    public init(key: String, value: JSONValue) {
        self.key = key
        self.value = value
    }
}

/// A JSON document. Objects keep their keys in document order and numbers keep their original spelling.
public enum JSONValue: Sendable, Equatable {
    case object([JSONMember])
    case array([JSONValue])
    case string(String)
    /// The number exactly as it was written, e.g. `12`, `-0.5`, `1e9`.
    case number(String)
    case bool(Bool)
    case null
}

public struct JSONParseError: Error, Sendable, Equatable, CustomStringConvertible {
    public let message: String
    /// Offset, in bytes, where parsing stopped.
    public let offset: Int

    public var description: String { "\(message) (at byte \(offset))" }
}

// MARK: - Parsing

public extension JSONValue {

    /// Parses UTF-8 encoded JSON.
    init(data: Data) throws {
        self = try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> JSONValue in
            var parser = JSONParser(bytes: raw.bindMemory(to: UInt8.self))
            return try parser.parseDocument()
        }
    }

    init(string: String) throws {
        try self.init(data: Data(string.utf8))
    }
}

private struct JSONParser {
    let bytes: UnsafeBufferPointer<UInt8>
    var index = 0

    private static let maxDepth = 512

    init(bytes: UnsafeBufferPointer<UInt8>) {
        self.bytes = bytes
    }

    mutating func parseDocument() throws -> JSONValue {
        // UTF-8 byte order mark.
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            index = 3
        }
        skipWhitespace()
        let value = try parseValue(depth: 0)
        skipWhitespace()
        guard index == bytes.count else { throw error("Unexpected content after the end of the document") }
        return value
    }

    private func error(_ message: String) -> JSONParseError {
        JSONParseError(message: message, offset: index)
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D: index += 1
            default: return
            }
        }
    }

    private mutating func parseValue(depth: Int) throws -> JSONValue {
        guard depth <= Self.maxDepth else { throw error("The document is nested too deeply") }
        guard index < bytes.count else { throw error("Unexpected end of the document") }

        switch bytes[index] {
        case UInt8(ascii: "{"):
            return try parseObject(depth: depth)
        case UInt8(ascii: "["):
            return try parseArray(depth: depth)
        case UInt8(ascii: "\""):
            return .string(try parseString())
        case UInt8(ascii: "t"):
            try consume(literal: "true")
            return .bool(true)
        case UInt8(ascii: "f"):
            try consume(literal: "false")
            return .bool(false)
        case UInt8(ascii: "n"):
            try consume(literal: "null")
            return .null
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
            return .number(try parseNumber())
        default:
            throw error("Unexpected character")
        }
    }

    private mutating func consume(literal: StaticString) throws {
        let count = literal.utf8CodeUnitCount
        guard index + count <= bytes.count else { throw error("Unexpected end of the document") }
        let matches = literal.withUTF8Buffer { expected in
            (0..<count).allSatisfy { bytes[index + $0] == expected[$0] }
        }
        guard matches else { throw error("Unexpected character") }
        index += count
    }

    private mutating func parseObject(depth: Int) throws -> JSONValue {
        index += 1 // {
        var members: [JSONMember] = []
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
            index += 1
            return .object(members)
        }

        while true {
            skipWhitespace()
            guard index < bytes.count else { throw error("Unterminated object") }
            guard bytes[index] == UInt8(ascii: "\"") else { throw error("Expected a key") }
            let key = try parseString()
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { throw error("Expected ':'") }
            index += 1
            skipWhitespace()
            let value = try parseValue(depth: depth + 1)
            members.append(JSONMember(key: key, value: value))
            skipWhitespace()
            guard index < bytes.count else { throw error("Unterminated object") }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
            } else if bytes[index] == UInt8(ascii: "}") {
                index += 1
                return .object(members)
            } else {
                throw error("Expected ',' or '}'")
            }
        }
    }

    private mutating func parseArray(depth: Int) throws -> JSONValue {
        index += 1 // [
        var elements: [JSONValue] = []
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
            index += 1
            return .array(elements)
        }

        while true {
            skipWhitespace()
            elements.append(try parseValue(depth: depth + 1))
            skipWhitespace()
            guard index < bytes.count else { throw error("Unterminated array") }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
            } else if bytes[index] == UInt8(ascii: "]") {
                index += 1
                return .array(elements)
            } else {
                throw error("Expected ',' or ']'")
            }
        }
    }

    private mutating func parseNumber() throws -> String {
        let start = index
        if bytes[index] == UInt8(ascii: "-") {
            index += 1
        }
        guard consumeDigits() else { throw error("Invalid number") }
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            index += 1
            guard consumeDigits() else { throw error("Invalid number") }
        }
        if index < bytes.count, bytes[index] == UInt8(ascii: "e") || bytes[index] == UInt8(ascii: "E") {
            index += 1
            if index < bytes.count, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") {
                index += 1
            }
            guard consumeDigits() else { throw error("Invalid number") }
        }
        return String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<index]), as: UTF8.self)
    }

    /// Returns `false` when there is no digit at the current position.
    private mutating func consumeDigits() -> Bool {
        let start = index
        while index < bytes.count, bytes[index] >= UInt8(ascii: "0"), bytes[index] <= UInt8(ascii: "9") {
            index += 1
        }
        return index > start
    }

    private mutating func parseString() throws -> String {
        index += 1 // opening quote
        let start = index

        // Fast path: no escape sequence.
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "\"") {
                let string = String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<index]), as: UTF8.self)
                index += 1
                return string
            }
            if byte == UInt8(ascii: "\\") { break }
            index += 1
        }
        guard index < bytes.count else { throw error("Unterminated string") }

        var buffer = [UInt8](bytes[start..<index])
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "\"") {
                index += 1
                return String(decoding: buffer, as: UTF8.self)
            }
            guard byte == UInt8(ascii: "\\") else {
                buffer.append(byte)
                index += 1
                continue
            }

            index += 1
            guard index < bytes.count else { break }
            let escaped = bytes[index]
            index += 1
            switch escaped {
            case UInt8(ascii: "b"): buffer.append(0x08)
            case UInt8(ascii: "f"): buffer.append(0x0C)
            case UInt8(ascii: "n"): buffer.append(0x0A)
            case UInt8(ascii: "r"): buffer.append(0x0D)
            case UInt8(ascii: "t"): buffer.append(0x09)
            case UInt8(ascii: "u"):
                appendUnicodeEscape(to: &buffer)
            default:
                // `\"`, `\\`, `\/`, and anything else is kept as is.
                buffer.append(escaped)
            }
        }
        throw error("Unterminated string")
    }

    /// Reads the 4 hex digits following `\u` (and a second escape for surrogate pairs).
    private mutating func appendUnicodeEscape(to buffer: inout [UInt8]) {
        guard let first = readHexQuad() else {
            buffer.append(contentsOf: "\u{FFFD}".utf8)
            return
        }
        var scalarValue = first
        if (0xD800...0xDBFF).contains(first) {
            let saved = index
            if index + 1 < bytes.count, bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") {
                index += 2
                if let second = readHexQuad(), (0xDC00...0xDFFF).contains(second) {
                    scalarValue = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
                } else {
                    index = saved
                }
            }
        }
        let scalar = Unicode.Scalar(scalarValue) ?? "\u{FFFD}"
        buffer.append(contentsOf: String(Character(scalar)).utf8)
    }

    private mutating func readHexQuad() -> UInt32? {
        guard index + 4 <= bytes.count else { return nil }
        var value: UInt32 = 0
        for offset in 0..<4 {
            let byte = bytes[index + offset]
            let digit: UInt32
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = UInt32(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = UInt32(byte - UInt8(ascii: "a")) + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = UInt32(byte - UInt8(ascii: "A")) + 10
            default: return nil
            }
            value = (value << 4) | digit
        }
        index += 4
        return value
    }
}

// MARK: - Serialization

public extension JSONValue {

    /// The JSON text of the value.
    func serialized(prettyPrinted: Bool = true, indent: String = "  ") -> String {
        var output = ""
        write(to: &output, prettyPrinted: prettyPrinted, indent: indent, level: 0)
        return output
    }

    /// The text of a scalar as it should be shown to a user: strings are quoted and escaped.
    /// Containers return a short summary.
    var displayText: String {
        switch self {
        case .object(let members): return members.isEmpty ? "{}" : "{ \(members.count) }"
        case .array(let elements): return elements.isEmpty ? "[]" : "[ \(elements.count) ]"
        case .string(let string): return JSONValue.quoted(string)
        case .number(let number): return number
        case .bool(let bool): return bool ? "true" : "false"
        case .null: return "null"
        }
    }

    /// The raw content of a scalar, handy for copying: strings are returned without quotes.
    /// Containers return their pretty-printed JSON.
    var copyText: String {
        switch self {
        case .string(let string): return string
        case .object, .array: return serialized()
        default: return displayText
        }
    }

    var isContainer: Bool {
        switch self {
        case .object, .array: return true
        default: return false
        }
    }

    var childCount: Int {
        switch self {
        case .object(let members): return members.count
        case .array(let elements): return elements.count
        default: return 0
        }
    }

    private func write(to output: inout String, prettyPrinted: Bool, indent: String, level: Int) {
        switch self {
        case .object(let members):
            guard !members.isEmpty else {
                output += "{}"
                return
            }
            output += "{"
            for (position, member) in members.enumerated() {
                if position > 0 { output += "," }
                if prettyPrinted {
                    output += "\n"
                    output += String(repeating: indent, count: level + 1)
                }
                output += JSONValue.quoted(member.key)
                output += prettyPrinted ? ": " : ":"
                member.value.write(to: &output, prettyPrinted: prettyPrinted, indent: indent, level: level + 1)
            }
            if prettyPrinted {
                output += "\n"
                output += String(repeating: indent, count: level)
            }
            output += "}"

        case .array(let elements):
            guard !elements.isEmpty else {
                output += "[]"
                return
            }
            output += "["
            for (position, element) in elements.enumerated() {
                if position > 0 { output += "," }
                if prettyPrinted {
                    output += "\n"
                    output += String(repeating: indent, count: level + 1)
                }
                element.write(to: &output, prettyPrinted: prettyPrinted, indent: indent, level: level + 1)
            }
            if prettyPrinted {
                output += "\n"
                output += String(repeating: indent, count: level)
            }
            output += "]"

        default:
            output += displayText
        }
    }

    /// Quotes and escapes a string the way JSON requires.
    static func quoted(_ string: String) -> String {
        var result = "\""
        result.reserveCapacity(string.utf8.count + 2)
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        result += "\""
        return result
    }
}
