import Foundation

/// 聊天消息模型
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String

    enum Role: Equatable {
        case user
        case assistant
        case system
    }

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}