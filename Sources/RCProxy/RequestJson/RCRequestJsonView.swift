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

    init(viewModel: RCRequestJsonViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            ForEach(Array(viewModel.lines.enumerated()), id: \.element.id) { index, line in
                JSONCell(line: line) { [line, index] isExpanded in
                    if isExpanded {
                        viewModel.expand(blockId: line.blockId, at: index)
                    } else {
                        viewModel.collapse(blockId: line.blockId)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
        }
        .environment(\.defaultMinListRowHeight, 1)
    }
}

struct JSONCell: View {
    @StateObject var line: JSONLine
    var tapAction: (Bool) -> Void

    var body: some View {
        Button {
            if line.isExpandable {
                line.isExpanded.toggle()
                tapAction(line.isExpanded)
            }
        } label: {
            HStack {
                if line.isExpandable {
                    Text(line.isExpanded ? "▼" : "▶︎")
                } else {
                    Text("•")
                }

                Text(line.value)
                    .font(.system(size: 16))

            }
            .padding(.leading, 32*CGFloat(line.indentLevel))
        }
    }
}
