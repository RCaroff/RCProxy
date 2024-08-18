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
            Text("{ }")
                .font(.title)
            Text("No request")
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
}

struct FilterViewTV: View {
    let buttonSize: CGFloat = 60.0

    @Binding var isErrorFiltered: Bool
    @Binding var isSuccessFiltered: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 100) {
            Button {
                isErrorFiltered.toggle()
            } label: {
                Group {
                    if isErrorFiltered {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .resizable()
                    } else {
                        Image(systemName: "exclamationmark.octagon")
                            .resizable()
                    }
                }
                .fixedSize()
                .frame(width: buttonSize, height: buttonSize, alignment: .center)
            }
            .tint(.red)
            .fixedSize()
            .frame(width: buttonSize, height: buttonSize, alignment: .center)

            Button {
                isSuccessFiltered.toggle()
            } label: {
                Group {
                    if isSuccessFiltered {
                        Image(systemName: "checkmark.diamond.fill")
                            .resizable()
                    } else {
                        Image(systemName: "checkmark.diamond")
                            .resizable()
                    }
                }
                .fixedSize()
                .frame(width: buttonSize, height: buttonSize, alignment: .center)
            }
            .tint(.green)


        }
        .buttonStyle(.bordered)
        .padding()

    }
}

struct FilterView: View {

    let buttonSize: CGFloat = 35.0

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
                            .resizable()
                    } else {
                        Image(systemName: "exclamationmark.octagon")
                            .resizable()
                    }
                }
                .padding(8)
            }
            .tint(.red)
            .frame(width: buttonSize, height: buttonSize)

            Button {
                isSuccessFiltered.toggle()
            } label: {
                Group {
                    if isSuccessFiltered {
                        Image(systemName: "checkmark.diamond.fill")
                            .resizable()
                    } else {

                        Image(systemName: "checkmark.diamond")
                            .resizable()
                    }
                }
                .padding(7)
            }
            .tint(.green)
            .frame(width: buttonSize, height: buttonSize)
        }

    }
}

struct ListContentView: View {

    @ObservedObject var viewModel: RCRequestsListViewModel
    @State private var showDetails: Bool = false
    @State var showDeleteConfirmation: Bool = false
    @State var showCopiedToast: Bool = false
    @State var isTapActive: Bool = false

    var body: some View {
        List {
            Section {
                ForEach(viewModel.items) { item in
                    ZStack {
                        RCRequestItemCell(item: item, navigationEnabled: true, onLongPress: {
#if os(iOS)
                            UIPasteboard.general.string = item.url
                            showCopiedToast = true
#endif
                        })
                    }

                }
            } header: {
                HStack {
                    Spacer()
#if os(iOS)
                    FilterView(
                        isErrorFiltered: $viewModel.isErrorFiltered,
                        isSuccessFiltered: $viewModel.isSuccessFiltered
                    )
#else
                    FilterViewTV(
                        isErrorFiltered: $viewModel.isErrorFiltered,
                        isSuccessFiltered: $viewModel.isSuccessFiltered
                    )
#endif
                    Spacer()
                }
            }
        }
        .listStyle(PlainListStyle())
#if os(iOS)
        .searchable(text: $viewModel.searchText)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
#endif
        .overlay {
            if viewModel.items.isEmpty {
                RequestsEmptyView()
            }
        }
        .navigationTitle("▶︎ Requests")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
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

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.fetch()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }
        .tint(.white)
        .toast(message: "URL copied", isShowing: $showCopiedToast, duration: Toast.short)
    }

}


struct RCRequestsListView: View {
    @ObservedObject var viewModel: RCRequestsListViewModel
    @State var showCopiedToast: Bool = false

    var body: some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            NavigationStack {
                ListContentView(viewModel: viewModel)
            }
            .tint(.white)
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
        } else {
            NavigationView {
                ListContentView(viewModel: viewModel)
            }
            .navigationViewStyle(.stack)
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
        }

    }
}

struct RCRequestItemCell: View {
    let item: RequestItem

    var navigationEnabled: Bool = false
    var onLongPress: () -> Void

    @State var isTapActive: Bool = false

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
        .background {
            if navigationEnabled {
                NavigationLink("", isActive: $isTapActive) {
                    RCRequestDetailsView(item: item)
                }
            }
        }
        .padding(.vertical, 4)
#if os(iOS)
        .onTapGesture {
            isTapActive.toggle()
        }
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred()
            onLongPress()
        }
#endif
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
