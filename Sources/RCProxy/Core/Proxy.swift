//
//  Proxy.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation

class RCProxyProtocol: URLProtocol {

    var dataTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: "is_handled", in: request) as? Bool == true {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let id = UUID().uuidString
        RCProxy.storage.store(request: RequestData(id: id, urlRequest: request, date: Date()))

        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "is_handled", in: mutableRequest)
        let newRequest = mutableRequest as URLRequest

        dataTask = RCProxy.urlSession.dataTask(with: newRequest, completionHandler: { [id] data, response, error in
            if let data = data, let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
            } else if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
            self.client?.urlProtocolDidFinishLoading(self)
            if let response = response as? HTTPURLResponse {
                RCProxy.storage.store(responseData: ResponseData(urlResponse: response, data: data), forRequestID: id)
            }
        })
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
    }
}
