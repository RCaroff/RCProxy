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

struct RequestsEmptyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
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
    }
}

struct FilterView: View {

    @Binding var isErrorFiltered: Bool
    @Binding var isSuccessFiltered: Bool

    var body: some View {
        HStack {
            Button {
                isErrorFiltered.toggle()
            } label: {
                Group {
                    if isErrorFiltered {
                        Image(systemName: "exclamationmark.octagon.fill")
                    } else {
                        Image(systemName: "exclamationmark.octagon")
                    }
                }
            }
            .tint(.red)
            Button {
                isSuccessFiltered.toggle()
            } label: {
                Group {
                    if isSuccessFiltered {
                        Image(systemName: "checkmark.diamond.fill")
                    } else {
                        Image(systemName: "checkmark.diamond")
                    }
                }
            }
            .tint(.green)
        }
    }
}

struct ListView: View {
    @Binding var items: [RequestItem]
    @Binding var isErrorFiltered: Bool
    @Binding var isSuccessFiltered: Bool

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    ZStack {
                        NavigationLink("") {
                            RCRequestDetailsView(item: item)
                        }
                        RCProxyRequestItemCell(item: item)
                    }
                }
            } header: {
                FilterView(
                    isErrorFiltered: $isErrorFiltered,
                    isSuccessFiltered: $isSuccessFiltered
                )
            }
        }
#if os(iOS)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .overlay {
            if items.isEmpty {
                RequestsEmptyView()
            }
        }
#endif
    }
}


struct RCRequestsListView: View {
    @ObservedObject var viewModel: RCRequestsListViewModel
    @State private var showDetails: Bool = false
    @State var showDeleteConfirmation: Bool = false

    var body: some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            NavigationStack {
                ListView(
                    items: $viewModel.items,
                    isErrorFiltered: $viewModel.isErrorFiltered,
                    isSuccessFiltered: $viewModel.isSuccessFiltered
                )
#if os(iOS)
                .searchable(text: $viewModel.searchText)
#endif
                .navigationTitle("Requests")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.white)
                        .alert("Are you sure ?", isPresented: $showDeleteConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete all", role: .destructive) {
                                viewModel.clear()
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.fetch()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .tint(.white)
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
