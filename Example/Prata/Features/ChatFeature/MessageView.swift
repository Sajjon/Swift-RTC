//
//  MessageView.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-09-05.
//

import Foundation
import SwiftUI

public struct MessageView: View {
    let message: ChatMessage
    public init(message: ChatMessage) {
        self.message = message
    }
    public var body: some View {
        HStack {
            messageStatusView
            Text(message.timestamp)
            contentView
        }
    }
}

private extension MessageView {
    var messageStatusView: some View {
        Text(message.messageStatusDescription)
    }
    
    @ViewBuilder
    var contentView: some View {
        switch message.content {
        case let .largeMessage(value):
            VStack {
                Text("Large #\(value.size) bytes msg")
                if value.isLoremIpsum {
                    Text(" (Lorem ipsum)")
                }
            }
        case let .smallMessage(value):
            Text(value)
        }
    }
}
