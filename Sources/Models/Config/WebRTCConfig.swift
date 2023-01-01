//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-27.
//

import Foundation
import Collections
import Tagged

extension OrderedSet: @unchecked Sendable where Element: Sendable {}

public struct WebRTCConfig: Sendable, Hashable, Codable {
    public let iceServers: [ICEServer]
    public let defineDtlsSrtpKeyAgreement: Bool
    public let eventsTriggeringReconnect: EventsTriggeringReconnect
    
    public init(
        defineDtlsSrtpKeyAgreement: Bool = true,
        eventsTriggeringReconnect: EventsTriggeringReconnect = .default,
        iceServers: [ICEServer] = [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302"
        ]
    ) {
        self.defineDtlsSrtpKeyAgreement = defineDtlsSrtpKeyAgreement
        self.iceServers = iceServers
        self.eventsTriggeringReconnect = eventsTriggeringReconnect
    }
    
    public static let `default` = Self()
}

public extension WebRTCConfig {
    enum EventsTriggeringReconnectTag: Hashable {}
    typealias EventsTriggeringReconnect = Tagged<EventsTriggeringReconnectTag, OrderedSet<RTCEvent>>
}

public extension WebRTCConfig.EventsTriggeringReconnect {
    static let `default`: Self = [.webRTC(.iceConnectionState(.failed))]
    var iceConnectionStates: OrderedSet<ICEConnectionState> {
        .init(self.compactMap { $0.webRTC?.iceConnectionState })
    }
    var sipEvents: OrderedSet<SessionInitiationProtocolEvent> {
        .init(self.compactMap({ $0.sessionInitiationProtocolEvent }))
    }
}
