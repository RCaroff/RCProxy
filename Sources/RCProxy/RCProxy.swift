//
//  RCProxy.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//

import Foundation
import UIKit
import SwiftUI
import os
import RCProxyCore

public final class RCProxy {

    /// The version of the library.
    public static let version = "4.1.0"

    public enum StorageType: Sendable {
        /// Stores request in a singleton. The requests will be available
        /// - parameter maxRequestsCount Limits the number of requests you want to store. Default: 100
        case session(maxRequestsCount: UInt = 100)

        /// Stores requests in `UserDefaults.standard`.
        /// - parameter maxRequestsCount Limits the number of requests you want to store. Default: 100
        case userDefaults(maxRequestsCount: UInt = 100)

        /// Stores requests in a sqlite database using SwiftData.
        /// - parameter maxRequestsCount Limits the number of requests you want to store. Default: 100
        case database(maxRequestsCount: UInt = 100)
    }

    private struct Configuration: Sendable {
        var storage: any RequestsStorage = SessionRequestsStorage(maxRequestsCount: 100)
        var urlSession: URLSession = .shared
    }

    /// `start` may be called from any thread while requests are being recorded on others.
    private static let configuration = OSAllocatedUnfairLock(initialState: Configuration())

    static var storage: any RequestsStorage {
        configuration.withLock { $0.storage }
    }

    /// The URLSession object you want to proxyfy.
    /// - default  `URLSession.shared`
    static var urlSession: URLSession {
        configuration.withLock { $0.urlSession }
    }

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

    /// The UIHostingController that host RCProxy navigation. You can use it for doing your own navigation.
    @MainActor
    public static var viewController: UIViewController {
        UIHostingController(rootView: view)
    }

    /// The main view that could be displayed inside your swiftUI navigation.
    @MainActor
    public static var view: some View {
        RCRequestsListView(viewModel: RCRequestsListViewModel(storage: storage))
    }

    /// Starts the proxy with the given storage type.
    /// - parameter urlSession: The URLSession object you want to proxyfy. Default: `URLSession.shared`
    /// - parameter storageType: The type of storage. Default value: ` .session(maxRequestsCount: UInt = 100)`
    public static func start(with urlSession: URLSession = URLSession.shared, storageType: StorageType = .session()) {
        let storage: any RequestsStorage
        switch storageType {
        case .session(let count):
            storage = SessionRequestsStorage(maxRequestsCount: count)
        case .userDefaults(let count):
            storage = UserDefaultsRequestsStorage(maxRequestsCount: count)
        case .database(let count):
            storage = SwiftDataRequestsStorage(maxRequestsCount: count)
        }
        configuration.withLock {
            $0.storage = storage
            $0.urlSession = urlSession
        }
        URLProtocol.registerClass(RCProxyProtocol.self)
        DesktopStreamer.shared.resumeIfEnabled()
    }

    /// Will present the RCProxy UI in modal way.
    /// - parameter viewController: The viewController that will present the RCProxy UI.
    @MainActor
    public static func show(in viewController: UIViewController) {
        viewController.present(RCProxy.viewController, animated: true)
    }
}
