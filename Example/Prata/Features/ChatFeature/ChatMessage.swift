//
//  ChatMessage.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-09-05.
//

import Foundation
import P2PConnection

public struct ChatMessage: Identifiable, Sendable, Hashable {
    
    public enum Content: Sendable, Hashable {
        case smallMessage(String)
        
        case largeMessage(LargeMessage)
    }
    
    public struct LargeMessage: Sendable, Hashable {
        
        /// Equal to byteCount for .utf8 encoded messages.
        public let size: Int
        public let isLoremIpsum: Bool
    }

    
    public typealias ID = P2PConnections.MessageID

    public private(set) var messageType: MessageType
    public let content: Content
    public let id: ID
    public let date: Date
    
    init(
        type messageType: MessageType,
        content: Content,
        id: ID,
        date: Date = .now
    ) {
        self.messageType = messageType
        self.content = content
        self.date = date
        self.id = id
    }
      
    public static func receivedInferIfGenerated(
        message: String,
        id: ID,
        date: Date = .now
    ) -> Self {
        let isLarge = message.count >= LoremIpsumGenerator.sizesInBytes.first!
        let firstPart = String(message.prefix(100)).lowercased()
        let isLoremIpsum = firstPart.contains("lorem") || firstPart.contains("ipsum")
        return Self(
            type: .incoming(.receivedButNotSentConfirmationBackToSender),
            content: isLarge ? .largeMessage(
                .init(size: message.count, isLoremIpsum: isLoremIpsum)
            ) : .smallMessage(message),
            id: id
        )
    }
}

public extension ChatMessage {
    
    enum MessageType: Sendable, Hashable {
        case outgoing(OutgoingStatus)
        case incoming(IncomingStatus)
    }
    
    var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        formatter.setLocalizedDateFormatFromTemplate("HH:mm:ss a")
        return formatter.string(from: date)
    }
}

public extension ChatMessage.MessageType {
    
    enum IncomingStatus: Sendable, Hashable {
        case receivedButNotSentConfirmationBackToSender
        case receivedAndConfirmed
    }
    
    enum OutgoingStatus: Sendable, Hashable {
        /// Dispatched to other client over WebRTC
        case sending
        /// Sent without failure, but not yet confirmed
        case sentButNotConfirmed
        /// Remote client has sent confirmation that it received our outgoing message
        case sendAndConfirmed
        /// Failed to send
        case failedToSend
    }
    
}

private extension ChatMessage.MessageType {
    
    var incomingStatus: IncomingStatus? {
        switch self {
        case let .incoming(value):
            return value
        case .outgoing:
            return nil
        }
    }
    
    var outgoingStatus: OutgoingStatus? {
        switch self {
        case .incoming:
            return nil
        case let .outgoing(value):
            return value
        }
    }
    
    var isOutgoing: Bool {
        outgoingStatus != nil
    }
    var isIncoming: Bool {
        incomingStatus != nil
    }
}
private extension ChatMessage {
    var isOutgoing: Bool {
        messageType.isOutgoing
    }
    
    var isIncoming: Bool {
        messageType.isIncoming
    }
    
    func newOutgoingStatus(_ newStatus: MessageType.OutgoingStatus) -> Self {
        precondition(isOutgoing)
        var copy = self
        copy.messageType = .outgoing(newStatus)
        return copy
    }
}

public extension ChatMessage {
    
    
    func newIncomingStatus(_ newStatus: MessageType.IncomingStatus) -> Self {
        precondition(isIncoming)
        var copy = self
        copy.messageType = .incoming(newStatus)
        return copy
    }
    
    func finishedSendingMessageReceivedConfirmation() -> Self {
        newIncomingStatus(.receivedAndConfirmed)
    }
}

public extension ChatMessage {
    func confirmed() -> Self {
        newOutgoingStatus(.sendAndConfirmed)
    }
    
    func failed() -> Self {
        newOutgoingStatus(.failedToSend)
    }
    
    func sending() -> Self {
        newOutgoingStatus(.sending)
    }
    
    func sendButNotConfirmed() -> Self {
        newOutgoingStatus(.sentButNotConfirmed)
    }
}


internal extension ChatMessage {
    var messageStatusDescription: String {
        [
            clientString,
            messageStatus
        ].joined(separator: "")
    }
    
    var clientString: String {
        if messageType.isIncoming {
            return "⬇️"
        } else {
            return "⬆️"
        }
    }
    
    var messageStatus: String {
        switch self.messageType {
        case let .incoming(status):
            switch status {
            case .receivedAndConfirmed:
                return "✅"
            case .receivedButNotSentConfirmationBackToSender:
                return "☑️"
            }
        case let .outgoing(status):
            switch status {
            case .sending:
                return "⏳"
            case .sentButNotConfirmed:
                return "☑️"
            case .sendAndConfirmed:
                return "✅"
            case .failedToSend:
                return "❌"
            }
        }
    }
}
