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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                Button(action: {}) {
                    StatusCodeBadgeView(code: item.statusCode, color: item.statusColor)
                }

                Text(item.url)
                Group {
                    Text("⬆️ Request")
                        .font(.system(size: 20, weight: .bold))
                        .padding()

                    Text("Headers")
                        .font(.system(size: 16, weight: .regular))

                    Text(item.requestHeaders.description
                        .replacingOccurrences(of: ", ", with: "\n")
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                    )
                    .font(.system(size: 14, weight: .thin))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                    Text("Body")
                        .font(.system(size: 16, weight: .regular))

                    Text(item.requestBody)
                        .font(.system(size: 14, weight: .thin))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }

                Group {
                    Text("⬇️ Response")
                        .font(.system(size: 20, weight: .bold))
                        .padding()

                    Text("Headers")
                        .font(.system(size: 16, weight: .regular))

                    Text(item.responseHeaders.description
                        .replacingOccurrences(of: ", ", with: "\n")
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                    )
                    .font(.system(size: 14, weight: .thin))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NavigationLink {
                        RCRequestJsonView(viewModel: RCRequestJsonViewModel(json: item.responseBodyJson))
                    } label: {
                        Text("Body")
                            .font(.system(size: 16, weight: .regular))
                    }
                }

            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)

    }
}

struct RCRequestDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        RCRequestDetailsView(item: RequestItem(
            url: "https://dev-api.fubo.tv/movies",
            requestHeaders: "x-access-token: fjdsbnobnzoge45e4gerg3",
            requestBody: "",
            responseHeaders: "x-country-code: US",
            responseBody: "{}",
            responseBodyJson: [:],
            statusCode: "400",
            statusColor: .systemRed
        ))
    }
}
