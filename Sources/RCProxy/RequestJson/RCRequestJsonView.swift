//
//  RCRequestJsonView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 31/10/2022.
//

import Foundation
import SwiftUI

enum ViewType: Int, CaseIterable {
    case json
    case text
}

struct RCRequestJsonView: View {
    @ObservedObject var viewModel: RCRequestJsonViewModel
    @State var showCopiedToast: Bool = false
    @State var isSharing: Bool = false
    
    @State var selectedView: ViewType = .json
    
    var minimumRowHeight: CGFloat { isTV ? 1.0 : 48.0 }
    
    init(viewModel: RCRequestJsonViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
#if os(iOS)
            if selectedView == .json {
                List {
                    ForEach($viewModel.lines) { $line in
                        JSONCell(line: $line) { [line] isExpanded in
                            UIImpactFeedbackGenerator(style: .medium)
                                .impactOccurred()
                            if isExpanded {
                                viewModel.expand(blockId: line.blockId)
                            } else {
                                viewModel.collapse(blockId: line.blockId)
                            }
                        } longPressAction: {
                            UIPasteboard.general.string = line.value
                            showCopiedToast = true
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
                }
                .animation(.easeOut(duration: 0.3), value: viewModel.lines.count)
                .environment(\.defaultMinListRowHeight, minimumRowHeight)
                .toast(message: "Copied!", isShowing: $showCopiedToast, duration: Toast.short)
            } else {
                TextEditor(text: $viewModel.prettyJson)
                    .padding(.horizontal)
            }
#else
            List {
                ForEach($viewModel.lines) { $line in
                    JSONCell(line: $line) { [line] isExpanded in
                        if isExpanded {
                            viewModel.expand(blockId: line.blockId)
                        } else {
                            viewModel.collapse(blockId: line.blockId)
                        }
                    } longPressAction: {}
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
            }
            .animation(.easeOut(duration: 0.3), value: viewModel.lines.count)
            .environment(\.defaultMinListRowHeight, minimumRowHeight)
#endif
        }
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
        .toolbar {
            Picker("", selection: $selectedView, content: {
                Text("JSON").tag(ViewType.json)
                Text("Text").tag(ViewType.text)
            })
            .pickerStyle(.segmented)
        }
        .sheet(isPresented: $isSharing, content: {
            if let url = viewModel.prettyJson.toJSONFile(withName: viewModel.jsonTitle) {
                ShareSheetView(activityItems: [url], callback: { (actType, _, _ , _) in
                    if actType == .copyToPasteboard {
                        UIPasteboard.general.string = viewModel.prettyJson
                    }
                })
            }
        })
#endif
    }
}

struct JSONCell: View {
    @Environment(\.colorScheme) var colorScheme
    var padding: CGFloat { isTV ? 32 : 8 }
    var fontSize: CGFloat { isTV ? 16 : 12 }
    
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
                    Text("▶︎")
                        .rotationEffect(.degrees(line.isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.1), value: line.isExpanded)
                } else {
                    Text("•")
                }
                
                Text(line.value)
                    .font(.system(size: fontSize))
                    .padding(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                
            }
            .padding(.leading, padding*CGFloat(line.indentLevel))
        }
        .tint(colorScheme == .dark ? .white : .black)
#if os(iOS)
        .onTapGesture {
            if line.isExpandable {
                tapAction(!line.isExpanded)
            }
        }
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred()
            longPressAction()
        }
#endif
    }
}
