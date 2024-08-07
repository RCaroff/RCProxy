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
    @Environment(\.dismiss) var dismiss
    @State var showDeleteConfirmation: Bool = false

    var body: some View {
        if viewModel.items.isEmpty {
            VStack {
                Text("🤷‍♀️")
                    .font(.title)
                Text("No request")
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                }
                .padding()
            }
        } else {
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
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .alert("Are you sure ?", isPresented: $showDeleteConfirmation) {
                                Button("Cancel", role: .cancel) { }
                                Button("Delete all", role: .destructive) {
                                    viewModel.clear()
                                }
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                viewModel.fetch()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                    }
                }
                .tint(.white)
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
            VStack(alignment: .leading, spacing: isTV ? 24 : 8) {
                HStack(spacing: isTV ? 24 : 8) {
                    StatusCodeBadgeView(code: "\(item.method) \(item.statusCode)", color: item.statusColor)

                    Text(item.dateString)
                        .font(.footnote)
                        .foregroundColor(Color(uiColor: .lightGray))
                    Spacer()
                }

#if os(iOS)
                Text(item.url)
                    .font(.system(size: fontSize))
#else
                Button {} label: {
                    Text(item.url)
                        .font(.system(size: fontSize))
                }
#endif

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
            .font(.footnote)
            .padding(isTV ? 8 : 4)
            .background(Color(color))
            .cornerRadius(isTV ? 8 : 4)
    }
}
