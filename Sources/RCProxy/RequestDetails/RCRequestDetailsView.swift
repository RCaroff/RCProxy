//
//  RCRequestDetailsView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 28/08/2022.
//

import SwiftUI
import RCProxyCore

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
                ForEach(item.queryParameters) { parameter in
                    QueryParameterRow(parameter: parameter, onLongPress: {
#if os(iOS)
                        UIPasteboard.general.string = parameter.value
                        showCopiedToast = true
#endif
                    })
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
                        prettyJson: item.requestHeaders.headersText,
                        jsonTitle: jsonTitle(withSuffix: "request-headers")
                    ))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
                .accessibilityIdentifier("RCProxy.details.requestHeaders")
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
                .accessibilityIdentifier("RCProxy.details.requestBody")
            }

            Section {
                NavigationLink {
                    RCRequestJsonView(viewModel: RCRequestJsonViewModel(
                        json: item.responseHeaders,
                        prettyJson: item.responseHeaders.headersText,
                        jsonTitle: jsonTitle(withSuffix: "response-headers")
                    ))
                } label: {
                    Text("Headers")
                        .font(.system(size: isTV ? 24 : 16, weight: .regular))
                }
                .accessibilityIdentifier("RCProxy.details.responseHeaders")

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
                .accessibilityIdentifier("RCProxy.details.responseBody")
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

struct QueryParameterRow: View {
    let parameter: QueryParameterItem
    var onLongPress: () -> Void

    var body: some View {
#if os(tvOS)
        // On tvOS every row must hold a focusable control. Otherwise the focus engine jumps over the
        // parameters, straight to a row that is still off screen, and the list does not scroll far
        // enough to reveal it: the request headers looked like they could not be focused, and the
        // parameters themselves could not be scrolled through.
        Button {} label: {
            content
        }
#else
        content
            .onLongPressGesture {
                UIImpactFeedbackGenerator(style: .rigid)
                    .impactOccurred()
                onLongPress()
            }
#endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(parameter.name)
                .font(.footnote)
                .foregroundColor(Color(uiColor: .lightGray))

            Text(parameter.value)
                .font(.system(size: isTV ? 24 : 14, weight: .regular))
        }
    }
}
