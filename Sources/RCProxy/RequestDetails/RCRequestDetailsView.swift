//
//  RCRequestDetailsView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 28/08/2022.
//

import SwiftUI

struct RCRequestDetailsView: View {

    @State var isSharing: Bool = false

    let item: RequestItem

    var body: some View {

        List {
            HStack(spacing: isTV ? 24 : 8) {
                StatusCodeBadgeView(code: item.statusCode, color: item.statusColor)
                Text(item.url)
                    .font(.system(size: isTV ? 32 : 14, weight: .regular))
            }
            .padding(4)

            Section {
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.requestHeaders,
                        prettyJson: item.requestHeaders.prettyfiedHeaders()
                    ))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.requestBodyJson,
                        prettyJson: item.requestBody
                    ))
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
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.responseHeaders,
                        prettyJson: item.responseHeaders.prettyfiedHeaders()
                    ))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }

                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.responseBodyJson,
                        prettyJson: item.responseBody
                    ))
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
        .navigationTitle(URL(string: item.url)?.relativePath ?? "")
        #if os(iOS)
        .toolbar {
            Button(action: {
                isSharing = true
            }, label: {
                Image(systemName: "square.and.arrow.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            })
        }
        .sheet(isPresented: $isSharing, content: {
            ShareSheetView(activityItems: [item.cURL])
        })
        #endif
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
            statusColor: .systemRed,
            cURL: ""
        ))
    }
}
