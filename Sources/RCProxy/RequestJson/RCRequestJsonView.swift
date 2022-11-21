//
//  RCRequestJsonView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 31/10/2022.
//

import Foundation
import SwiftUI

struct RCRequestJsonView: View {
    @ObservedObject var viewModel: RCRequestJsonViewModel
    @State var showCopiedToast: Bool = false
    @State var isSharing: Bool = false

    var minimumRowHeight: CGFloat {
        if isTV {
            return 1.0
        }
        return 48.0
    }

    init(viewModel: RCRequestJsonViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            ForEach($viewModel.lines) { $line in
                JSONCell(line: $line) { [line] isExpanded in
                    if isExpanded {
                        viewModel.expand(blockId: line.blockId)
                    } else {
                        viewModel.collapse(blockId: line.blockId)
                    }
                } longPressAction: {
                    #if os(iOS)
                    UIPasteboard.general.string = line.value
                    showCopiedToast = true
                    #endif
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
        }
        .environment(\.defaultMinListRowHeight, minimumRowHeight)
        .toast(message: "Copied!", isShowing: $showCopiedToast, duration: Toast.short)
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
            if let url = viewModel.prettyJson.toJSONFile(withName: viewModel.jsonTitle) {
                ShareSheetView(activityItems: [url])
            }
        })
#endif
    }
}

struct JSONCell: View {

    var padding: CGFloat {
        if isTV {
            return 32
        }
        return 8
    }

    var fontSize: CGFloat {
        if isTV {
            return 16
        }
        return 12
    }

    @Binding var line: JSONLine
    var tapAction: (Bool) -> Void
    var longPressAction: () -> Void

    var body: some View {
        Button {
            if line.isExpandable {
                tapAction(!line.isExpanded)
            }
        } label: {
            HStack {
                if line.isExpandable {
                    Text(line.isExpanded ? "▼" : "▶︎")
                } else {
                    Text("•")
                }

                Text(line.value)
                    .font(.system(size: fontSize))
                    .padding(.init(top: 8, leading: 0, bottom: 8, trailing: 0))

            }
            .padding(.leading, padding*CGFloat(line.indentLevel))
        }

        #if os(iOS)
        .onTapGesture {
            if line.isExpandable {
                tapAction(!line.isExpanded)
            }
        }
        .onLongPressGesture { longPressAction() }
        #endif
    }
}
