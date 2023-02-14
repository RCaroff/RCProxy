//
//  RequestsStorage.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation
import CoreData

struct RequestData: Hashable {
    let id: String
    let urlRequest: URLRequest
    let date: Date
}

struct ResponseData: Hashable {
    let urlResponse: HTTPURLResponse
    let data: Data?
}

protocol RequestsStorage {
    var requestItems: [RequestItem] { get set }
    func store(request: RequestData)
    func store(responseData: ResponseData, forRequestID id: String)
    func clear()
}
