//
//  RCRequestDetailsView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 28/08/2022.
//

import SwiftUI

struct RCRequestDetailsView: View {

    @State var isSharing: Bool = false
    @State var showCopiedToast: Bool = false

    let item: RequestItem

    var body: some View {
        List {
            RCRequestItemCell(item: item, onLongPress: {
#if os(iOS)
                UIPasteboard.general.string = item.url
                showCopiedToast = true
#endif
            })
            Section {
                ForEach(item.queryParameters) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name)
                            .font(.footnote)
                            .foregroundColor(Color(uiColor: .lightGray))

                        Text(item.value)
                            .font(.system(size: isTV ? 24 : 14, weight: .regular))

                    }
#if os(iOS)
                    .onLongPressGesture {
                        UIImpactFeedbackGenerator(style: .rigid)
                            .impactOccurred()
                        UIPasteboard.general.string = item.value
                        showCopiedToast = true
                    }
#endif
                }
            } header: {
                Text("▲ Request")
                    .font(.system(size: isTV ? 32 : 20, weight: .bold))
                    .padding()
            }

            Section {
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.requestHeaders,
                        prettyJson: item.requestHeaders.prettyfiedHeaders(),
                        jsonTitle: jsonTitle(withSuffix: "request-headers")
                    ))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.requestBodyJson,
                        prettyJson: item.requestBody,
                        jsonTitle: jsonTitle(withSuffix: "request-body")
                    ))
                } label: {
                    Text("Body")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
            }

            Section {
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.responseHeaders,
                        prettyJson: item.responseHeaders.prettyfiedHeaders(),
                        jsonTitle: jsonTitle(withSuffix: "response-headers")
                    ))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }

                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.responseBodyJson,
                        prettyJson: item.responseBody,
                        jsonTitle: jsonTitle(withSuffix: "response-body")
                    ))
                } label: {
                    Text("Body")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
            } header: {
                Text("▼ Response")
                    .font(.system(size: isTV ? 32 : 20, weight: .bold))
                    .padding()
            }
        }
        .navigationTitle(item.relativePath)
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
            ShareSheetView(activityItems: [item.cURL], callback: nil)
        })
        .toast(message: "Copied", isShowing: $showCopiedToast, duration: Toast.short)
#endif

    }

    func jsonTitle(withSuffix suffix: String) -> String {
        "\(item.relativePath.dropFirst().replacingOccurrences(of: "/", with: "-"))_\(suffix)"
    }
}
