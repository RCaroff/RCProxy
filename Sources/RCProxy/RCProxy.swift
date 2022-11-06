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

    static let storage: RequestsStorage = SessionRequestsStorage()

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
