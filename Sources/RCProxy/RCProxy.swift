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
        case database
    }

    static var storage: RequestsStorage = SessionRequestsStorage()

    public static var storageType: StorageType = .session {
        didSet {
            switch storageType {
            case .session:
                storage = SessionRequestsStorage()
            case .userDefaults:
                storage = UserDefaultsRequestsStorage()
            case .database:
                storage = CoreDataRequestsStorage()
            }
        }
    }

    public static var viewController: UIViewController {
        UIHostingController(rootView: view)
    }

    public static var view: some View {
        RCRequestsListView(viewModel: RCRequestsListViewModel(storage: storage))
            .preferredColorScheme(.dark)
    }

    public static func start() {
        URLProtocol.registerClass(RCProxyProtocol.self)
    }

    public static func show(in viewController: UIViewController) {
        viewController.present(RCProxy.viewController, animated: true)
    }
}
