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
            return data.toJSON()
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
    func toJSON() -> String {
        do {
            let jsonObject: AnyObject = try JSONSerialization.jsonObject(with: self) as AnyObject
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "No content"
        } catch {
            return "No content"
        }
    }

    func toJSONObject() -> [String: Any] {
        do {
            let jsonObject: Dictionary<String, Any>? = try JSONSerialization.jsonObject(with: self) as? Dictionary<String, Any>
            return jsonObject ?? [:]
        } catch {
            return [:]
        }
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

        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8),  !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }

        cURL += method + url + header + data

        return cURL
    }
}