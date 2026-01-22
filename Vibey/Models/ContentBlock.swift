//
//  ContentBlock.swift
//  Vibey
//
//  Data model for rich content blocks
//

import Foundation

enum BlockType {
    case text
    case header
    case checkbox
    case bullet
}

struct ContentBlock: Identifiable, Codable {
    let id: UUID
    var type: BlockType
    var text: String
    var isChecked: Bool

    init(id: UUID = UUID(), type: BlockType = .text, text: String = "", isChecked: Bool = false) {
        self.id = id
        self.type = type
        self.text = text
        self.isChecked = isChecked
    }
}

// Make BlockType Codable
extension BlockType: Codable {
    enum CodingKeys: String, CodingKey {
        case text, header, checkbox, bullet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "text": self = .text
        case "header": self = .header
        case "checkbox": self = .checkbox
        case "bullet": self = .bullet
        default: self = .text
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text: try container.encode("text")
        case .header: try container.encode("header")
        case .checkbox: try container.encode("checkbox")
        case .bullet: try container.encode("bullet")
        }
    }
}
