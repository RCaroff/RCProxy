//
//  RCProxyView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//
import SwiftUI

var isTV: Bool {
    UIDevice.current.userInterfaceIdiom == .tv
}

struct RCRequestsListView: View {
    @ObservedObject var viewModel: RCRequestsListViewModel
    @State private var showDetails: Bool = false

    var body: some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            NavigationStack {
                List {
                    ForEach(viewModel.items) { item in
                        ZStack {
                            NavigationLink("") {
                                RCRequestDetailsView(item: item)
                            }
                            RCProxyRequestItemCell(item: item)
                        }
                    }
                }
                .navigationTitle("Requests")
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        } else {
            NavigationView {
                List {
                    ForEach(viewModel.items) { item in
                        ZStack {
                            NavigationLink("") {
                                RCRequestDetailsView(item: item)
                            }
                            RCProxyRequestItemCell(item: item)
                        }
                    }
                }
                .navigationTitle("Requests")
            }
            .navigationViewStyle(.stack)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }

    }
}

struct RCProxyRequestItemCell: View {
    let item: RequestItem

    var fontSize: CGFloat {
        if isTV {
            return 24
        }
        return 14
    }

    var body: some View {
        ZStack {
            HStack(spacing: isTV ? 24 : 8) {
                StatusCodeBadgeView(code: "\(item.method) \(item.statusCode)", color: item.statusColor)
                Text(item.url)
                    .font(.system(size: fontSize))
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusCodeBadgeView: View {
    let code: String
    let color: UIColor

    var body: some View {
        Text(code)
            .padding(8)
            .background(Color(color))
            .cornerRadius(8)
    }
}

struct RCProxyView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = RCRequestsListViewModel(storage: RCProxy.storage)
        viewModel.items = [
            RequestItem(
                url: "https://swapi.dev/api/people",
                method: "GET",
                requestHeaders: ["x-access-token": "fjdsbnobnzoge45e4gerg3"],
                requestBody: "",
                requestBodyJson: [:],
                responseHeaders: ["x-country-code": "US"],
                responseBody: "{}",
                responseBodyJson: [:],
                statusCode: "200",
                statusColor: .systemGreen,
                cURL: ""
            ),
            RequestItem(
                url: "https://swapi.dev/api/people",
                method: "GET",
                requestHeaders: ["x-access-token": "fjdsbnobnzoge45e4gerg3"],
                requestBody: "",
                requestBodyJson: [:],
                responseHeaders: ["x-country-code": "US"],
                responseBody: "{}",
                responseBodyJson: [:],
                statusCode: "400",
                statusColor: .systemRed,
                cURL: ""
            )
        ]
        return RCRequestsListView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
}
