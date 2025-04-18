//
//  RCProxy.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation
import UIKit
import SwiftUI

public final class RCProxy {

    public enum StorageType {
        /// Stores request in a singleton. The requests will be available
        /// - parameter maxRequestsCount Limits the number of requests you want to store. Default: 100
        case session(maxRequestsCount: UInt = 100)

        /// Stores requests in `UserDefaults.standard`.
        /// - parameter maxRequestsCount Limits the number of requests you want to store. Default: 100
        case userDefaults(maxRequestsCount: UInt = 100)

        /// Stores requests in a sqlite database using CoreData.
        /// - parameter maxRequestsCount Limits the number of requests you want to store. Default: 100
        case database(maxRequestsCount: UInt = 100)
    }

    static var storage: RequestsStorage = SessionRequestsStorage(maxRequestsCount: 100)

    /// The URLSession object you want to proxyfy.
    /// - default  `URLSession.shared`
    static var urlSession: URLSession = URLSession.shared

    /// Use this configuration for your custom URLSession, instead of URLSessionConfiguration.default
    public static var defaultConfiguration: URLSessionConfiguration {
        let conf = URLSessionConfiguration.default
        conf.protocolClasses = [RCProxyProtocol.self]
        return conf
    }

    /// Use this configuration for your custom URLSession, instead of URLSessionConfiguration.ephemeral
    public static var ephemeralConfiguration: URLSessionConfiguration {
        let conf = URLSessionConfiguration.ephemeral
        conf.protocolClasses = [RCProxyProtocol.self]
        return conf
    }


    /// The type of storage you want to use.
    /// - Default: `.session()`
    static var storageType: StorageType = .session() {
        didSet {
            switch storageType {
            case .session(let count):
                storage = SessionRequestsStorage(maxRequestsCount: count)
            case .userDefaults(let count):
                storage = UserDefaultsRequestsStorage(maxRequestsCount: count)
            case .database(let count):
                storage = CoreDataRequestsStorage(maxRequestsCount: count)
            }
        }
    }

    /// The UIHostingController that host RCProxy navigation. You can use it for doing your own navigation.
    public static var viewController: UIViewController {
        UIHostingController(rootView: view)
    }

    /// The main view that could be displayed inside your swiftUI navigation.
    public static var view: some View {
        RCRequestsListView(viewModel: RCRequestsListViewModel(storage: storage))
    }

    /// Starts the proxy with the given storage type.
    /// - parameter urlSession: The URLSession object you want to proxyfy. Default: `URLSession.shared`
    /// - parameter storageType: The type of storage. Default value: ` .session(maxRequestsCount: UInt = 100)`
    public static func start(with urlSession: URLSession = URLSession.shared, storageType: StorageType = .session()) {
        RCProxy.storageType = storageType
        RCProxy.urlSession = urlSession
        URLProtocol.registerClass(RCProxyProtocol.self)
    }


    /// Will present the RCProxy UI in modal way.
    /// - parameter viewController: The viewController that will present the RCProxy UI.
    public static func show(in viewController: UIViewController) {
        viewController.present(RCProxy.viewController, animated: true)
    }
}
