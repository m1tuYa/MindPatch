

import Foundation

enum BlockType: String, Codable {
    case board, post, text, heading1, heading2, list, checkbox
}

struct Block: Identifiable, Codable {
    var id: String
    var type: BlockType
    var content: String
    var parentId: String?
    var postId: String?
    var boardId: String?
    var order: Float
    var createdAt: Date
    var updatedAt: Date
    var status: String? // "draft", "published", "archived"
    var tags: [String]?
    var isPinned: Bool?
    var isCollapsed: Bool?
    var style: String?
    var props: [String: AnyCodable]?
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
