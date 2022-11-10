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

    var minimumRowHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .tv {
            return 1.0
        }
        return 48.0
    }

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
        .environment(\.defaultMinListRowHeight, minimumRowHeight)
    }
}

struct JSONCell: View {

    var padding: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .tv {
            return 32
        }
        return 8
    }

    var fontSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .tv {
            return 16
        }
        return 12
    }

    @StateObject var line: JSONLine
    var tapAction: (Bool) -> Void

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
    }
}
