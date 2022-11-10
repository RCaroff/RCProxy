//
//  RCRequestDetailsView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 28/08/2022.
//

import SwiftUI



struct RCRequestDetailsView: View {

    let item: RequestItem

    var body: some View {

        List {
            HStack(spacing: 8) {
                StatusCodeBadgeView(code: item.statusCode, color: item.statusColor)
                Text(item.url)
                    .font(.system(size: isTV ? 32 : 14, weight: .regular))
            }

            Section {
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(json: item.requestHeaders))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(json: item.requestBodyJson))
                } label: {
                    Text("Body")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
            } header: {
                Text("⬆️ Request")
                    .font(.system(size: isTV ? 32 : 20, weight: .bold))
                    .padding()
            }

            Section {
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(json: item.responseHeaders))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }

                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(json: item.responseBodyJson))
                } label: {
                    Text("Body")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
            } header: {
                Text("⬇️ Response")
                    .font(.system(size: isTV ? 32 : 20, weight: .bold))
                    .padding()
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
    }
}

struct RCRequestDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        RCRequestDetailsView(item: RequestItem(
            url: "https://dev-api.fubo.tv/movies",
            requestHeaders: ["x-access-token": "fjdsbnobnzoge45e4gerg3"],
            requestBody: "",
            requestBodyJson: [:],
            responseHeaders: ["x-country-code": "US"],
            responseBody: "{}",
            responseBodyJson: [:],
            statusCode: "400",
            statusColor: .systemRed
        ))
    }
}
