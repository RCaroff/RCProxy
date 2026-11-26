//
//  File.swift
//
//
//  Created by Rémi Caroff on 13/11/2022.
//

import Foundation

extension Optional where Wrapped == Data {
    func toJSON() -> String {
        switch self {
        case .none:
            return "No content"
        case .some(let data):
            return data.toJSON() ?? String(data: data, encoding: .utf8) ?? "No content"
        }
    }

    func toJSONObject() -> [String: Any] {
        switch self {
        case .none:
            return [:]
        case .some(let data):
            return data.toJSONObject()
        }
    }
}

extension Data {
    func toJSON() -> String? {
        do {
            let value = try JSON.parse(data: self).toJSONString(prettyPrinted: true)
            return value
        } catch {
            return nil
        }
    }

    func toJSONObject() -> [String: Any] {
        do {
            if let jsonObject = try JSON.parse(data: self).toJSONObject() as? [String: Any] {
                return jsonObject
            } else {
                let jsonArray = toJSONArray()
                if jsonArray.isEmpty {
                    return [:]
                } else {
                    return ["": jsonArray]
                }
            }
        } catch {
            return [:]
        }
    }

    func toJSONArray() -> [Any] {
        do {
            let jsonObject: [Any]? = try JSON.parse(data: self).toJSONObject() as? [Any]
            return jsonObject ?? []
        } catch {
            return []
        }
    }
}

extension [String: Any] {
    func toData() -> Data? {
        return try? JSONSerialization.data(withJSONObject: self)
    }
}

extension String {
    func toJSONFile(withName name: String) -> URL? {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                            in: .userDomainMask).first {
            let pathWithFilename = documentDirectory.appendingPathComponent("\(name).json")
            do {
                try write(to: pathWithFilename,
                          atomically: true,
                          encoding: .utf8)
                return pathWithFilename
            } catch {
                return nil
            }
        }

        return nil
    }
}

extension [String: String] {
    func prettyfiedHeaders() -> String {
        return description
            .replacingOccurrences(of: ", ", with: "\n")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
    }
}

extension URLRequest {
    public func cURL(pretty: Bool = false) -> String {
        cURL(pretty: pretty, body: httpBody ?? bodyStream())
    }

    /// Builds the cURL command with an already read body, so that the body stream is only consumed once.
    func cURL(pretty: Bool = false, body: Data?) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(self.httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\(Self.shellQuoted(self.url?.absoluteString ?? "")) \(newLine)"

        var cURL = "curl "
        var header = ""
        var data: String = ""

        if let httpHeaders = self.allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key, value) in httpHeaders.sorted(by: { $0.key < $1.key }) {
                header += (pretty ? "--header " : "-H ") + "\(Self.shellQuoted("\(key): \(value)")) \(newLine)"
            }
        }

        if let body, !body.isEmpty, let bodyString = String(data: body, encoding: .utf8) {
            data = "--data \(Self.shellQuoted(bodyString))"
        }

        cURL += method + url + header + data

        return cURL
    }

    /// Wraps a value in single quotes, escaping the single quotes it contains.
    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Reads the body stream of the request. A stream can only be read once.
    func bodyStream() -> Data? {
        guard let bodyStream = self.httpBodyStream else { return nil }

        bodyStream.open()
        defer { bodyStream.close() }

        let bufferSize = 16 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()

        while bodyStream.hasBytesAvailable {
            let readCount = bodyStream.read(buffer, maxLength: bufferSize)
            // 0 means the end of the stream, a negative value means an error.
            guard readCount > 0 else { break }
            data.append(buffer, count: readCount)
        }

        return data
    }
}
