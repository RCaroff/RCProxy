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

    var body: some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            NavigationStack {
                List {
                    ForEach(viewModel.items) { item in
                        RCProxyRequestItemCell(item: item)
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
                        RCProxyRequestItemCell(item: item)
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

    @State private var showDetails: Bool = false

    var body: some View {
        Button {
            showDetails = true
        } label: {
            ZStack {
                HStack(spacing: isTV ? 24 : 8) {
                    StatusCodeBadgeView(code: item.statusCode, color: item.statusColor)
                    Text(item.url)
                        .font(.system(size: fontSize))
                    Spacer()
                }
                NavigationLink("", destination: RCRequestDetailsView(item: item), isActive: $showDetails)
            }
        }
        .padding(4)
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
                requestHeaders: ["x-access-token": "fjdsbnobnzoge45e4gerg3"],
                requestBody: "",
                requestBodyJson: [:],
                responseHeaders: ["x-country-code": "US"],
                responseBody: "{}",
                responseBodyJson: [:],
                statusCode: "200",
                statusColor: .systemGreen
            ),
            RequestItem(
                url: "https://swapi.dev/api/people",
                requestHeaders: ["x-access-token": "fjdsbnobnzoge45e4gerg3"],
                requestBody: "",
                requestBodyJson: [:],
                responseHeaders: ["x-country-code": "US"],
                responseBody: "{}",
                responseBodyJson: [:],
                statusCode: "400",
                statusColor: .systemRed
            )
        ]
        return RCRequestsListView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
}
