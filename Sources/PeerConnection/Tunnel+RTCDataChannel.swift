//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import AsyncExtensions
import Foundation
import WebRTC
import RTCModels

extension AnyAsyncIterator: @unchecked Sendable where Self.Element: Sendable {}
extension AnyAsyncSequence: @unchecked Sendable where Self.AsyncIterator: Sendable {}

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
                 try await tunnel.incomingMessages().map { data in
                    try await decoder.decode(data)
                }.eraseToAnyAsyncSequence()
            },
            send: { message in
                let data = try await encoder.encode(message)
                try await tunnel.send(data)
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

