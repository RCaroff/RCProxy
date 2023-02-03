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
        case session
        case userDefaults
    }

    static let storage: RequestsStorage = UserDefaultsRequestsStorage()

    public static var viewController: UIViewController {
        UIHostingController(rootView: RCRequestsListView(viewModel: RCRequestsListViewModel(storage: storage)))
    }

    public static func start() {
        URLProtocol.registerClass(RCProxyProtocol.self)
    }

    public static func show(in viewController: UIViewController) {
        viewController.present(RCProxy.viewController, animated: true)
    }
}
