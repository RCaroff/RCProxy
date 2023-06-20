//
//  JSON.swift
//  Tisander
//
//  Created by Mike Bignell on 22/06/2018.
//  Copyright © 2018 Mike Bignell. All rights reserved.
//

import Foundation

/**
 Errors when parsing JSON string
 */
public enum SerializationError: String, Error {
    /// Unterminated object. Opening curley brace without a close
    case unterminatedObject
    /// Unterminated Array. Opening square brackets without a close
    case unterminatedArray
    /// Unterminated string. Opening double quote without matching ending one
    case unterminatedString
    /// Invalid JSON
    case invalidJSON
    /// Invalid array element. One of the elements in the array was not valid
    case invalidArrayElement
    /// Number missing it's exponent part
    case invalidNumberMissingExponent
    /// Number was missing it's fractional element
    case invalidNumberMissingFractionalElement
    /// Reached the end of the file unexpectedly
    case unexpectedEndOfFile
}

/// Element of JSON structure, can be an array element or a key/value
public protocol JSONElement: Value {}

/// Any value for JSON, can be Object, array, number, string, boolean or null
public protocol Value {
    /**
     Subscript for getting values from keys
     - parameter key: key for value
     - returns: value for key. Also returns nil if it is not a key/value structure
     */
    subscript(key: String) -> Value? { get }
    /**
     Subscript for retrieving items from an array at index
     - parameter index: index for value
     - returns: value at index
     */
    subscript(index: Int) -> Value? { get }

    /**
     String representation of the JSON
     - returns: string with the json sub-value
     */
    func stringRepresentation(prettyPrinted: Bool, level: Int) -> String
    func jsonRepresentation() -> Any
}

extension Value {
    /**
     Convert a JSON object or array into a string
     - returns: String representation of the entire object
     */
    public func toJSONString(prettyPrinted: Bool) -> String {
        return stringRepresentation(prettyPrinted: prettyPrinted, level: 0)
    }

    public func toJSONObject() -> Any? {
        return jsonRepresentation()
    }
}

public extension Value {
    /**
     Subscript for getting values from keys
     - parameter key: key for value
     - returns: value for key. Also returns nil if it is not a key/value structure
     */
    subscript(key: String) -> Value? {
        get {
            return (self as? [JSON.ObjectElement])?.reduce(nil, { (result, element) -> Value? in
                guard result == nil else { return result }

                return element.key == key ? element.value : nil
            })
        }
    }
    /**
     Subscript for getting values from indexes
     - parameter index: index to retrieve
     - returns: value if index is valid and the subject is an array of `JSON.ArrayElement`s
     */
    subscript(index: Int) -> Value? {
        get {
            guard let elementArray = self as? [JSON.ArrayElement],
                  index >= 0,
                  index <  elementArray.count
            else { return nil }

            return ((elementArray as [Any])[index] as? JSON.ArrayElement)?.value
        }
    }

    /// Get all keys in the key/value set, returns nil if the array is not keys/values.
    var keys: [String]? {
        return (self as? [JSON.ObjectElement])?.compactMap { $0.key }
    }

    /// Get all values in the current structure
    var values: [Value]? {
        return (self as? [JSON.ArrayElement])?.map { $0.value } ?? (self as? [JSON.ObjectElement])?.map { $0.value }
    }
}

extension Bool: Value {
    /**
     Return the string representation of this boolean
     - returns: either 'true' or 'false'
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String { return self ? "true" : "false" }
    public func jsonRepresentation() -> Any { return self ? "true" : "false" }
}
extension Int: Value {
    /**
     Return the string representation of this integer
     - returns: integer as string
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String { return String(self) }
    public func jsonRepresentation() -> Any { return String(self) }
}
extension Double: Value {
    /**
     Return the string representation of this double precision floating point number
     - returns: double as string. Uses default system number formatter
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String { return String(self) }
    public func jsonRepresentation() -> Any { return String(self) }
}
extension String: Value {
    /**
     Return the string
     - returns: string in quotes
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String { return "\"\(self)\"" }
    public func jsonRepresentation() -> Any { return self }
}
extension JSON.ArrayElement: JSONElement {
    /**
     Return the string representation of this array element
     - returns: string representation of this array element
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String {
        return "\(self.value.stringRepresentation(prettyPrinted: prettyPrinted, level: level))"
    }
    public func jsonRepresentation() -> Any {
        return value.jsonRepresentation()
    }
}
extension JSON.ObjectElement: JSONElement {
    /**
     Return the string representation of this object
     - returns: string representation of this object with a "key":value
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String {
        return "\"\(self.key)\": \(self.value.stringRepresentation(prettyPrinted: prettyPrinted, level: level))"
    }

    public func jsonRepresentation() -> Any {
        return value.jsonRepresentation()
    }
}
extension JSON.NULL: Value {
    /**
     Return the string representation of this null
     - returns: "null"
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String { return "null" }
    public func jsonRepresentation() -> Any { return "null" }
}

extension Int {
    var indent: String {
        return (0..<Swift.max(0, self)).map { _ in "\t" }.joined()
    }
}

extension Array: Value where Array.Element: JSONElement {
    /**
     Return the string representation of this JSON structure
     - returns: string representation of this JSON structure
     */
    public func stringRepresentation(prettyPrinted: Bool, level: Int) -> String {
        if prettyPrinted {
            let indent = level.indent
            let nextIndent = (level+1).indent

            if Array.Element.self == JSON.ObjectElement.self {
                return "{\n\(nextIndent)\( (self as? [JSON.ObjectElement])?.map { $0.stringRepresentation(prettyPrinted: true, level: level+1) }.joined(separator: ",\n\(nextIndent)") ?? "" )\n\(indent)}"
            } else if Array.Element.self == JSON.ArrayElement.self {
                return "[\n\(nextIndent)\( (self as? [JSON.ArrayElement])?.map { $0.stringRepresentation(prettyPrinted: true, level: level+1) }.joined(separator: ",\n\(nextIndent)") ?? "" )\n\(indent)]"
            }
        } else {
            if Array.Element.self == JSON.ObjectElement.self {
                return "{\( (self as? [JSON.ObjectElement])?.map { $0.stringRepresentation(prettyPrinted: false, level: 0) }.joined(separator: ",") ?? "" )}"
            } else if Array.Element.self == JSON.ArrayElement.self {
                return "[\( (self as? [JSON.ArrayElement])?.map { $0.stringRepresentation(prettyPrinted: false, level: 0) }.joined(separator: ",") ?? "" )]"
            }
        }

        return ""
    }

    public func jsonRepresentation() -> Any {

        if let self = self as? [JSON.ObjectElement] {
            var json: [String: Any] = [:]

            self.enumerated().forEach { index, element in
                json["\(index)\(keyIndexSeparator)\(element.key)"] = element.jsonRepresentation()
            }

            return json

        } else if let self = self as? [JSON.ArrayElement] {
            let json: [Any] = self.map { $0.jsonRepresentation() }
            return json
        } else {
            return self.jsonRepresentation()
        }
    }

}

extension [String: Any] {
    func ordered() ->  Array<(String, Any)> {
        return self.sorted(by: { e1, e2 in
            guard let e1IndexString = e1.key.components(separatedBy: keyIndexSeparator).first,
                  let e1Index = Int(e1IndexString),
                  let e2IndexString = e2.key.components(separatedBy: keyIndexSeparator).first,
                  let e2Index = Int(e2IndexString) else {
                return true
            }

            return e1Index < e2Index
        }).map { element in
            return (String(element.key.components(separatedBy: keyIndexSeparator).last ?? ""), element.value)
        }
    }
}

private let keyIndexSeparator = "{+RC+}"

/**
 Create a representation of the JSON document that is parsed. Does not use Apple's `JSONSerialization` class and therefore keeps the order of the keys in the set as it's enountered.
 */
open class JSON {
    /// Representation for null value
    public class NULL {}

    /// Array element representation
    public struct ArrayElement {

        /// Array element value
        public let value: Value

        public init(value: Value) {
            self.value = value
        }
    }

    /// Object element representation
    public struct ObjectElement {

        /// Object element key
        public let key: String
        /// Object element value
        public let value: Value

        public init(key: String, value: Value) {
            self.key = key
            self.value = value
        }
    }

    /**
     Return a JSON structure value

     - parameter string: String representation of JSON
     - returns: An array of `ArrayElement`s or `ObjectElement`s
     - throws: `SerializationError`
     */
    public static func parse(string: String) throws -> Value {
        guard !string.isEmpty else { throw SerializationError.invalidJSON }

        let json = JSON()

        var index = string.startIndex

        // Run space parser to remove beginning spaces
        _ = json.spaceParser(string, index: &index)

        if let arrayElements = try json.arrayParser(string, index: &index) {
            return arrayElements
        } else if let objectElements = try json.objectParser(string, index: &index) {
            return objectElements
        }

        throw SerializationError.invalidJSON
    }

    public static func parse(data: Data) throws -> Value {
        let stringData = String(data: data, encoding: .utf8) ?? ""
        return try parse(string: stringData)
    }

    /**
     Function to parse object

     Starts by checking for a {
     Next checks for the key of the object
     finally the value of the key
     Uses - KeyParser,SpaceParser,valueParser and endofsetParser
     Finally checks for the end of the main Object with a }

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: An array of `ObjectElemet`s
     - throws: `SerializationError.unterminatedObject`
     */
    private func objectParser(_ jsonString: String, index: inout String.Index) throws -> [ObjectElement]? {
        guard index != jsonString.endIndex, jsonString[index] == "{" else { return nil }

        var parsedDict = [ObjectElement]()
        index = jsonString.index(after: index)

        while true {
            if let key = try keyParser(jsonString,index: &index) {
                _ = spaceParser(jsonString, index: &index)

                guard let _ = colonParser(jsonString, index: &index) else { return nil }

                if let value = try valueParser(jsonString, index: &index) {
                    parsedDict.append(ObjectElement(key: key, value: value))
                }

                _ = spaceParser(jsonString, index: &index)

                if let _ = endOfSetParser(jsonString, index: &index) {
                    return parsedDict
                }
            } else if index == jsonString.endIndex {
                throw SerializationError.unterminatedObject
            } else if jsonString[index] == "}" || isSpace(jsonString[index]) {
                _ = spaceParser(jsonString, index: &index)

                guard let _ = endOfSetParser(jsonString, index: &index) else {
                    throw SerializationError.unterminatedObject
                }

                return parsedDict
            } else {
                break
            }
        }

        return nil
    }

    /**
     Function to check key value in an object

     Uses SpaceParser and StringParser

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: Key string or nil
     - throws: `SerializationError`
     */
    private func keyParser(_ jsonString: String, index: inout String.Index) throws -> String? {
        _ = spaceParser(jsonString, index: &index)

        return try stringParser(jsonString, index: &index) ?? nil
    }

    /**
     Function to check for a colon

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: Colon or null
     */
    @discardableResult
    private func colonParser(_ jsonString: String, index: inout String.Index) -> String? {
        guard index != jsonString.endIndex, jsonString[index] == ":" else { return nil }

        index = jsonString.index(after: index)

        return ":"
    }

    /**
     Function to check value in an object

     SpaceParser to remove spaces
     pass it to the elemParser
     stores the returned element in a variable called value
     after which the string is then passed to the space and comma parser

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: a JSON value
     - throws: `SerializationError`
     */
    private func valueParser(_ jsonString:String, index: inout String.Index) throws -> Value? {
        _ = spaceParser(jsonString, index: &index)

        guard let value = try elemParser(jsonString, index: &index) else { return nil }

        _ = spaceParser(jsonString, index: &index)
        _ = commaParser(jsonString, index: &index)

        return value
    }

    /**
     Function to check end of object

     Checks for a }

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: a closing curley brace
     */
    @discardableResult
    private func endOfSetParser(_ jsonString:String, index: inout String.Index) -> Bool? {
        guard jsonString[index] == "}" else { return nil }

        index = jsonString.index(after: index)

        return true
    }

    /**
     Function to parser an array

     Starts by checking for a [
     After which it is passed to an elemParser store the returned value in another array called parsed array
     Uses elemParser,SpaceParser,commaParser,endOfArrayParser
     Finally checks for a ] to mark the end of the array

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: an array of elements
     - throws: `SerializationError`
     */
    private func arrayParser(_ jsonString: String, index: inout String.Index) throws -> [ArrayElement]? {
        guard jsonString[index] == "[" else { return nil }

        var parsedArray = [ArrayElement]()
        index = jsonString.index(after: index)

        while true {
            if let returnedElem = try elemParser(jsonString, index: &index) {
                parsedArray.append(ArrayElement(value: returnedElem))
                _ = spaceParser(jsonString, index: &index)

                if let _ = commaParser(jsonString, index: &index) {

                } else if let _ = endOfArrayParser(jsonString, index: &index) {
                    return parsedArray
                } else {
                    return nil
                }
            } else if index == jsonString.endIndex {
                throw SerializationError.unterminatedArray
            } else if jsonString[index] == "]" || isSpace(jsonString[index]) {
                _ = spaceParser(jsonString, index: &index)

                guard let _ = endOfArrayParser(jsonString, index: &index) else {
                    throw SerializationError.unterminatedArray
                }

                return parsedArray
            } else {
                throw SerializationError.invalidArrayElement
            }
        }
    }

    /**
     Parsing elements in Array or value in a key/value pair

     Uses StringParser,numberParser,arrayParser,objectParser and nullParser

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: element
     - throws: `SerializationError`
     */
    private func elemParser(_ jsonString:String, index: inout String.Index) throws -> Value? {
        guard index != jsonString.endIndex else { throw SerializationError.unexpectedEndOfFile }
        _ = spaceParser(jsonString, index: &index)

        if let value = try stringParser(jsonString, index: &index) {
            return value
        } else if let value = try numberParser(jsonString, index: &index) {
            return value
        } else if let value = booleanParser(jsonString, index: &index) {
            return value
        } else if let value = try arrayParser(jsonString, index: &index) {
            return value
        } else if let value = try objectParser(jsonString, index: &index) {
            return value
        } else if let value = nullParser(jsonString, index: &index) {
            return value
        }

        return nil
    }

    /**
     Function to check end of array

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: boolean
     */
    private func endOfArrayParser(_ jsonString:String, index: inout String.Index) -> Bool? {
        guard index != jsonString.endIndex, jsonString[index] == "]" else { return nil }

        index = jsonString.index(after: index)

        return true
    }

    /**
     Function to check for a whitespace character

     - parameter character: Character to test for being a space
     - returns: boolean
     */
    private func isSpace(_ character: Character) -> Bool {
        return [" ", "\t", "\n"].contains(character)
    }

    /**
     Space parser

     Uses `isSpace` function

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: spaces captured or nil if there was no spaces
     */
    @discardableResult
    private func spaceParser(_ jsonString: String, index: inout String.Index) -> String? {
        guard index != jsonString.endIndex, isSpace(jsonString[index]) else { return nil }

        let startingIndex = index

        while index != jsonString.endIndex {
            guard isSpace(jsonString[index]) else { break }

            index = jsonString.index(after: index)
        }

        return String(jsonString[startingIndex ..< index])
    }

    /**
     Function to check for a single digit

     - parameter character: Character to test if it is a digit
     - returns: boolean for if the character is a digit
     */
    private func isDigit(_ character: Character) -> Bool {
        return "0" ... "9" ~= character
    }

    /**
     Function to consume a number

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: spaces captured or nil if there was no spaces
     */
    private func consumeNumber(_ jsonString: String, index: inout String.Index) {
        while isDigit(jsonString[index]) {
            guard jsonString.index(after: index) != jsonString.endIndex else { break }

            index = jsonString.index(after: index)
        }
    }

    /**
     Number parser

     This method check all json valid numbers including exponents

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: Number value, usually either `Double` or `Int`
     - throws: `SerializationError`
     */
    private func numberParser(_ jsonString: String, index: inout String.Index) throws -> Value? {
        let startingIndex = index

        // When number is negative i.e. starts with "-"
        if jsonString[startingIndex] == "-" {
            guard jsonString.index(after: index) != jsonString.endIndex else { return nil }

            index = jsonString.index(after: index)
        }

        guard isDigit(jsonString[index]) else { return nil }

        consumeNumber(jsonString,index: &index)

        // For decimal points
        if jsonString[index] == "." {
            guard jsonString.index(after: index) != jsonString.endIndex else { return nil }

            index = jsonString.index(after: index)

            guard isDigit(jsonString[index]) else {
                throw SerializationError.invalidNumberMissingFractionalElement
            }

            consumeNumber(jsonString,index: &index)
        }

        // For exponents
        if String(jsonString[index]).lowercased() == "e" {
            guard jsonString.index(after: index) != jsonString.endIndex else { return nil }

            index = jsonString.index(after: index)

            if jsonString[index] == "-" || jsonString[index] == "+" {
                index = jsonString.index(after: index)
            }

            guard isDigit(jsonString[index]) else {
                throw SerializationError.invalidNumberMissingExponent
            }

            consumeNumber(jsonString,index: &index)
        }

        guard let double = Double(jsonString[startingIndex ..< index]) else { return nil }

        return (double.truncatingRemainder(dividingBy: 1.0) == 0.0 && double <= Double(Int.max)) ? Int(double) : double
    }

    /**
     String parser

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: String value that was parsed
     - throws: `SerializationError`
     */
    private func stringParser(_ jsonString: String, index: inout String.Index) throws -> String? {
        guard index != jsonString.endIndex, jsonString[index] == "\"" else { return nil }

        index = jsonString.index(after: index)
        let startingIndex = index

        while index != jsonString.endIndex {
            if jsonString[index] == "\\" {
                index = jsonString.index(after: index)

                if jsonString[index] == "\"" {
                    index = jsonString.index(after: index)
                } else {
                    continue
                }
            } else if jsonString[index] == "\"" {
                break
            } else {
                index = jsonString.index(after: index)
            }
        }

        let parsedString = String(jsonString[startingIndex ..< index])

        guard index != jsonString.endIndex else {
            index = startingIndex
            throw SerializationError.unterminatedString
        }

        index = jsonString.index(after: index)

        return parsedString
    }

    /**
     Comma parser

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: Comma or nil if none was found
     */
    @discardableResult
    private func commaParser(_ jsonString: String, index: inout String.Index) -> String? {
        guard index != jsonString.endIndex, jsonString[index] == "," else { return nil }

        index = jsonString.index(after: index)
        return ","
    }

    /**
     Boolean parser

     advances the index by 4 and checks for true or by 5 and checks for false

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: Result of boolean parser or nil if wasn't found
     */
    private func booleanParser(_ jsonString: String, index: inout String.Index) -> Bool? {
        let startingIndex = index

        if let advancedIndex = jsonString.index(index, offsetBy: 4, limitedBy: jsonString.endIndex) {
            index = advancedIndex
        } else {
            return nil
        }

        if jsonString[startingIndex ..< index] == "true" {
            return true
        }

        if index != jsonString.endIndex {
            index = jsonString.index(after: index)

            if jsonString[startingIndex ..< index]  == "false" {
                return false
            }
        }

        index = startingIndex

        return nil
    }

    /**
     Null parser

     Advances the index by 4 and checks for null

     - parameter jsonString: String representation of JSON
     - parameter index: Current index in json document
     - returns: Result of boolean parser or nil if wasn't found
     */
    private func nullParser(_ jsonString: String, index: inout String.Index) -> NULL? {
        let startingIndex = index

        if let advancedIndex = jsonString.index(index, offsetBy: 4, limitedBy: jsonString.endIndex) {
            index = advancedIndex
        } else {
            return nil
        }

        if jsonString[startingIndex ..< index].lowercased() == "null" {
            return NULL()
        }

        index = startingIndex

        return nil
    }
}
