//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import AsyncExtensions
import Foundation
import WebRTC
import P2PModels
import Tunnel


enum Error: String, LocalizedError, Sendable {
    case channelIsNotOpen
}

public extension Tunnel where ID == DataChannelID, ReadyState == DataChannelState {
    static func live(
        tunnel: Tunnel<DataChannelID, DataChannelState, Data, Data>,
        encoder: Encoder,
        decoder: Decoder
    ) -> Self {

        Self.multicast(
            getID: tunnel.id,
            readyStateAsyncSequence: { try await tunnel.readyStateUpdates() },
            incomingMessagesAsyncSequence: {
                 try await tunnel.incomingMessages().compactMap { data in
                    try await decoder.decode(data)
                }.eraseToAnyAsyncSequence()
            },
            send: { message in
                let dataMessages = try await encoder.encode(message)
                for dataMessage in dataMessages {
                    try await tunnel.send(dataMessage)
                }
            },
            close: {
                await tunnel.disconnect()
            }
        )
    }
}

internal extension Tunnel where
    ID == DataChannelID,
    ReadyState == DataChannelState,
    IncomingMessage == Data,
    OutgoingMessage == Data
{
    static func multicast(
        dataChannel: RTCDataChannel,
        dataChannelDelegate: DataChannelDelegate
    ) -> Self {
        Self.multicast(
            getID: dataChannelDelegate.dataChannelID,
            readyStateAsyncSequence: dataChannelDelegate.readyStateAsyncSequence,
            incomingMessagesAsyncSequence: dataChannelDelegate.messageReceivedAsyncSequence,
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

