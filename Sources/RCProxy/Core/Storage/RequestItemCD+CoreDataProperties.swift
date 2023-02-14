//
//  RequestItemCD+CoreDataProperties.swift
//  RCProxy-example
//
//  Created by Rémi Caroff on 14/02/2023.
//
//

import Foundation
import CoreData


extension RequestItemCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RequestItemCD> {
        return NSFetchRequest<RequestItemCD>(entityName: "RequestItemCD")
    }

    @NSManaged public var cURL: String
    @NSManaged public var date: Date
    @NSManaged public var id: String
    @NSManaged public var method: String
    @NSManaged public var requestBodyData: Data?
    @NSManaged public var requestHeaders: Data?
    @NSManaged public var responseBodyData: Data?
    @NSManaged public var responseHeaders: Data?
    @NSManaged public var statusCode: Int16
    @NSManaged public var url: String

}

extension RequestItemCD : Identifiable {

}
