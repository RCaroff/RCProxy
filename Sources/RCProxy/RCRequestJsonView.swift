//
//  RCRequestJsonView.swift
//  RCProxy
//
//  Created by Rémi Caroff on 31/10/2022.
//

import Foundation
import SwiftUI

class JSONBlock: ObservableObject, Identifiable {
    enum ValueType {
        case array
        case object
        case simple
    }

    var id: String
    var text: String = "{}"
    var isExpanded: Bool = false
    var type: ValueType = .simple
    var subBlocks: [JSONBlock] = []
    var isExpandable: Bool {
        return !subBlocks.isEmpty
    }

    init(id: String) {
        self.id = id
    }
}

class RCRequestJsonViewModel: ObservableObject {

    var json: [String: Any]

    @Published var lines: [JSONLine] = []
    @Published var jsonBlock: JSONBlock = JSONBlock(id: UUID().uuidString)

    private var allLines: [JSONLine] = []

    init(json: [String: Any]) {
        self.json = ["{ ... }": json]
        jsonBlock = buildBlock(with: self.json, parentBlockId: nil, indentLevel: 0)
        formatLines()
    }

    func buildBlock(with json: [String: Any], parentBlockId: String?, indentLevel: Int) -> JSONBlock {
        let block = JSONBlock(id: UUID().uuidString)
        json.forEach { (key, value) in
            if let value = value as? [String: Any] {
                value.forEach { key, value in
                    block.subBlocks.append(
                        buildBlock(
                            with: [key: value],
                            parentBlockId: block.id,
                            indentLevel: indentLevel+1
                        )
                    )
                }

                block.text = "\"\(key)\": {"
                block.type = .object

            } else if let value = value as? [[String: Any]] {
                block.type = .array

                value.enumerated().forEach {
                    block.subBlocks.append(
                        buildBlock(
                            with: ["[\($0)]": $1],
                            parentBlockId: block.id,
                            indentLevel: indentLevel+1
                        )
                    )
                }
                block.text = "\"\(key)\": [ \(value.count) elements ]"

            } else {
                block.type = .simple
                block.text = "\"\(key)\": \(value)"
            }
        }

        allLines.append(JSONLine(
            id: UUID(),
            blockId: block.id,
            parentBlockId: parentBlockId,
            value: block.text,
            indentLevel: indentLevel,
            isExpandable: !block.subBlocks.isEmpty)
        )

        return block
    }

    func formatLines() {
        lines = jsonBlock.subBlocks.map({ block in
            JSONLine(
                id: UUID(),
                blockId: block.id,
                value: block.text,
                indentLevel: 0,
                isExpandable: !block.subBlocks.isEmpty
            )
        })
    }

    func expand(blockId: String, at index: Int) {
        let linesToAdd = allLines.filter {
            $0.parentBlockId == blockId
        }.sorted { line1, line2 in
            line1.indentLevel > line2.indentLevel
        }

        lines.insert(contentsOf: linesToAdd, at: index+1)
    }

    func collapse(blockId: String, parentBlock: JSONBlock? = nil) {
        guard let selectedLineIndex = lines.firstIndex(where: { $0.blockId == blockId }) else { return }
        let selectedLine = lines[selectedLineIndex]
        var indicesToRemove: IndexSet = []
        for index in lines.indices {
            guard index > selectedLineIndex else { continue }
            let currentLine = lines[index]
            if currentLine.indentLevel > selectedLine.indentLevel {
                indicesToRemove.insert(index)
                currentLine.isExpanded = false
            } else {
                break
            }
        }

        lines.remove(atOffsets: indicesToRemove)
    }
}

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
