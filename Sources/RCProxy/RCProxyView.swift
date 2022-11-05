//
//  RCProxyView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 27/08/2022.
//
import SwiftUI

struct RCProxyView: View {
    @ObservedObject var viewModel: RCProxyViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.items) { item in
                    RCProxyRequestItemCell(item: item)
                }
            }
        }
    }
}

struct RCProxyRequestItemCell: View {
    let item: RequestItem

    @State private var showDetails: Bool = false

    var body: some View {
        Button {
            showDetails = true
        } label: {
            ZStack {
                HStack {
                    StatusCodeBadgeView(code: item.statusCode, color: item.statusColor)
                    Text(item.url)
                        .font(.body)
                    Spacer()
                }
                NavigationLink("", destination: RCRequestDetailsView(item: item), isActive: $showDetails)
            }
        }
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
        let viewModel = RCProxyViewModel(storage: RCProxy.storage)
        viewModel.items = [
            RequestItem(
                url: "https://dev-api.fubo.tv/movies",
                requestHeaders: "x-access-token: fjdsbnobnzoge45e4gerg3",
                requestBody: "",
                responseHeaders: "x-country-code: US",
                responseBody: "{}",
                responseBodyJson: [:],
                statusCode: "200",
                statusColor: .systemGreen
            ),
            RequestItem(
                url: "https://dev-api.fubo.tv/movies",
                requestHeaders: "x-access-token: fjdsbnobnzoge45e4gerg3",
                requestBody: "",
                responseHeaders: "x-country-code: US",
                responseBody: "{}",
                responseBodyJson: [:],
                statusCode: "400",
                statusColor: .systemRed
            )
        ]
        return RCProxyView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
}
