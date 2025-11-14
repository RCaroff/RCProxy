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
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(self.httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(self.url?.absoluteString ?? "")\' \(newLine)"

        var cURL = "curl "
        var header = ""
        var data: String = ""

        if let httpHeaders = self.allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key,value) in httpHeaders {
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }

        if let body = self.bodyStreamAsJSON() as? [String: Any],
           let bodyData = body.toData(),
           let bodyString = String(data: bodyData, encoding: .utf8),
           !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }

        cURL += method + url + header + data

        return cURL
    }

    func bodyStream() -> Data? {
        guard let bodyStream = self.httpBodyStream else { return nil }

        bodyStream.open()

        // Will read 16 chars per iteration. Can use bigger buffer if needed
        let bufferSize: Int = 16

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        var dat = Data()

        while bodyStream.hasBytesAvailable {

            let readDat = bodyStream.read(buffer, maxLength: bufferSize)
            dat.append(buffer, count: readDat)
        }

        buffer.deallocate()

        bodyStream.close()

        return dat
    }

    func bodyStreamAsJSON() -> Any? {
        guard let dat = bodyStream() else { return nil }

        do {
            return try JSON.parse(data: dat).toJSONObject()
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}
