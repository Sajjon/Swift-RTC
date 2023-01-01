//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import Foundation
import WebRTC
import RTCModels

enum Error: String, LocalizedError, Sendable {
    case channelIsNotOpen
}

internal extension Tunnel
where
ID == DataChannelID,
ReadyState == DataChannelState,
IncomingMessage == Data,
OutgoingMessage == Data
{
    static func live(
        dataChannel: RTCDataChannel,
        dataChannelDelegate: DataChannelDelegate
    ) -> Self {
        return Self.live(
            getID: dataChannelDelegate.dataChannelID,
            readyStateAsyncStream: dataChannelDelegate.readyStateAsyncSequence,
            incomingMessagesAsyncStream: dataChannelDelegate.messageReceivedAsyncSequence,
            send: { data in
                guard dataChannel.readyState == .open else {
                    throw Error.channelIsNotOpen
                }
                dataChannel.sendData(
                    .init(
                        data: data,
                        isBinary: true
                    )
                )
            },
            close: {
                dataChannel.close()
                dataChannel.delegate = nil
            }
        )
    }
}

