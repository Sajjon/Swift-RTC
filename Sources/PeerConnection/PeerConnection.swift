//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import RTCModels

public protocol PeerConnectionDelegate: AnyObject {
    
}

public final class PeerConnection:
    NSObject,
    RTCPeerConnectionDelegate,
    RTCDataChannelDelegate,
    Identifiable
{
   
    public let id: ID
    public let config: WebRTCConfig
    
    private unowned let delegate: PeerConnectionDelegate

    private let peerConnection: RTCPeerConnection
    
    public init(
        id: PeerConnectionID,
        config: WebRTCConfig,
        delegate: PeerConnectionDelegate
    ) throws {
        self.id = id
        self.config = config
        self.delegate = delegate
        
        guard
            let peerConnection = RTCPeerConnectionFactory().peerConnection(
                with: config.rtc(),
                constraints: .init(
                    mandatoryConstraints: nil,
                    optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
                ),
                delegate: nil
            )
        else {
            throw Error.failedToCreatePeerConnection
        }
        
        self.peerConnection = peerConnection
        super.init()
        
        self.peerConnection.delegate = self
    }
}

public extension PeerConnection {
    typealias ID = PeerConnectionID
    enum Error: String, LocalizedError, Sendable {
        case failedToCreatePeerConnection
    }
}

// MARK: RTCPeerConnectionDelegate
public extension PeerConnection {
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection id: \(id), didOpen dataChannel:\(dataChannel.channelId)")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection id: \(id), should Negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        let state = stateChanged.swiftify()
        debugPrint("peerConnection id: \(id), didChange SignalingState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let state = newState.swiftify()
        debugPrint("peerConnection id: \(id), didChange IceConnectionState to: \(state)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection id: \(id), didRemove stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("peerConnection id: \(id), didAdd stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let state = newState.swiftify()
        debugPrint("peerConnection id: \(id), didChange IceGatheringState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        debugPrint("peerConnection id: \(id), didGenerate ICE")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("peerConnection id: \(id), didRemove #\(candidates.count) ICE candidates")
    }
    
}

// MARK: RTCDataChannelDelegate
public extension PeerConnection {
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        debugPrint("peerConnection id: \(id), dataChannel=\(dataChannel.channelId) didReceiveMessageWith #\(buffer.data.count) bytes")
    }
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let readyState = dataChannel.readyState.swiftify()
        debugPrint("peerConnection id: \(id), dataChannel=\(dataChannel.channelId) dataChannelDidChangeState to: \(readyState)")
    }
}
