//
//  File.swift
//  
//
//  Created by Rémi Caroff on 06/11/2022.
//

import Foundation

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

class JSONLine: ObservableObject, Identifiable {
    let id: UUID
    let blockId: String
    let parentBlockId: String?
    let value: String
    let collapsedValue: String
    let indentLevel: Int
    let isExpandable: Bool
    @Published var isExpanded: Bool = false

    internal init(
        id: UUID,
        blockId: String,
        parentBlockId: String? = nil,
        value: String,
        indentLevel: Int,
        isExpandable: Bool
    ) {
        self.id = id
        self.blockId = blockId
        self.parentBlockId = parentBlockId
        self.value = value
        self.indentLevel = indentLevel
        self.collapsedValue = "{ ... }"
        self.isExpandable = isExpandable
    }
}

class RCRequestJsonViewModel: ObservableObject {

    @Published var lines: [JSONLine] = []

    private var jsonBlock: JSONBlock = JSONBlock(id: UUID().uuidString)
    private var allLines: [JSONLine] = []

    init(json: [String: Any]) {
        if json.isEmpty {
            lines = [JSONLine(id: UUID(), blockId: "", value: "No content", indentLevel: 0, isExpandable: false)]
        } else {
            jsonBlock = buildBlock(with: ["{ ... }": json], parentBlockId: nil, indentLevel: -1)
            formatLines()
        }
    }

    func expand(blockId: String, at index: Int) {
        lines[index].isExpanded = true
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
        selectedLine.isExpanded = false
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

    private func buildBlock(with json: [String: Any], parentBlockId: String?, indentLevel: Int) -> JSONBlock {
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

    private func formatLines() {
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
}
