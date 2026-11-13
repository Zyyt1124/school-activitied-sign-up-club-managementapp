package campus.service

import std.collection.*
import campus.domain.*
import campus.repository.*

public class MessageService {
    private let messages: MessageRepository

    public init(messages: MessageRepository) {
        this.messages = messages
    }

    public func list(actor: Actor): ArrayList<Message> {
        return messages.listByUser(actor.userId)
    }

    public func markRead(actor: Actor, messageId: Int64): Outcome<Bool, BizError> {
        if (messages.markRead(messageId, actor.userId)) {
            return succeed<Bool>(true)
        }
        return fail<Bool>(notFoundError("MESSAGE_NOT_FOUND", "消息不存在"))
    }
}
