//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import RTCModels

public final class PeerConnection:
    NSObject,
    Disconnecting,
    RTCPeerConnectionDelegate,
    RTCDataChannelDelegate
{
    internal struct ToChannel<Value: Sendable & Hashable>: Sendable, Hashable {
        let value: Value
        let channelID: DataChannelID
        init(_ value: Value, channelID: DataChannelID) {
            self.value = value
            self.channelID = channelID
        }
    }
    typealias DataToChannel = ToChannel<Data>
    typealias ConnectionStatusToChannel = ToChannel<DataChannelState>
    
    public let id: ID
    public let negotiationRole: NegotiationRole
    public let config: WebRTCConfig
    
    private let peerConnection: RTCPeerConnection
    
    typealias Channels = Disposables<Channel>
    private let channels: Channels = .init()
    
    public let shouldNegotiateAsyncSequence: AsyncStream<NegotiationRole>
    private let shouldNegotiateAsyncContinuation: AsyncStream<NegotiationRole>.Continuation
    
    public let generatedICECandidateAsyncSequence: AsyncStream<ICECandidate>
    private let generatedICECandidateAsyncContinutation: AsyncStream<ICECandidate>.Continuation
    
    public let removeICECandidatesAsyncSequence: AsyncStream<[ICECandidate]>
    private let removeICECandidatesAsyncContinutation: AsyncStream<[ICECandidate]>.Continuation
    
    private let dataToChannelAsyncSequence: AsyncStream<DataToChannel>
    private let dataToChannelAsyncContinuation: AsyncStream<DataToChannel>.Continuation
    
    private let connectionStatusToChannelAsyncSequence: AsyncStream<ConnectionStatusToChannel>
    private let connectionStatusToChannelAsyncContinuation: AsyncStream<ConnectionStatusToChannel>.Continuation
    deinit {
        debugPrint("deinit!!!!")
    }
    public init(
        id: PeerConnectionID,
        config: WebRTCConfig,
        negotiationRole: NegotiationRole
    ) throws {
        self.id = id
        self.config = config
        self.negotiationRole = negotiationRole
        
        guard
            let peerConnection = RTCPeerConnectionFactory().peerConnection(
                with: config.rtc(),
                constraints: .init(
                    mandatoryConstraints: nil,
                    optionalConstraints: nil//[dtlsSRTPKeyAgreement: kRTCMediaConstraintsValueTrue]
                ),
                delegate: nil
            )
        else {
            throw Error.failedToCreatePeerConnection
        }
        
        self.peerConnection = peerConnection
 
        (shouldNegotiateAsyncSequence, shouldNegotiateAsyncContinuation) = AsyncStream.streamWithContinuation(NegotiationRole.self)
        
        (generatedICECandidateAsyncSequence, generatedICECandidateAsyncContinutation) = AsyncStream.streamWithContinuation(ICECandidate.self)
        
        (removeICECandidatesAsyncSequence, removeICECandidatesAsyncContinutation) = AsyncStream.streamWithContinuation([ICECandidate].self)
        
        (dataToChannelAsyncSequence, dataToChannelAsyncContinuation) = AsyncStream.streamWithContinuation(DataToChannel.self)
        
        (connectionStatusToChannelAsyncSequence, connectionStatusToChannelAsyncContinuation) = AsyncStream.streamWithContinuation(ConnectionStatusToChannel.self)
        
        super.init()
        
        self.peerConnection.delegate = self
    }
}

public extension PeerConnection {
    typealias ID = PeerConnectionID
    enum Error: String, LocalizedError, Sendable {
        case failedToCreatePeerConnection
        case failedToCreateDataChannel
    }
}
private let dtlsSRTPKeyAgreement = "DtlsSrtpKeyAgreement"
private extension PeerConnection {
    static var negotiationConstraints: RTCMediaConstraints {
        .init(mandatoryConstraints: [:], optionalConstraints: [:])
    }
    
    @discardableResult
    func add(id: DataChannelID, dataChannel: RTCDataChannel) async throws -> Channel {
        
        dataChannel.delegate = self
        let channel = Channel(
            id: id,
            dataChannel: dataChannel
        )
        let task = Task { [unowned self] in
            
            await withThrowingTaskGroup(of: Void.self) { group in
                
                // Update connectionStatus
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await connectionStatus in self.connectionStatusToChannelAsyncSequence
                        .filter({ $0.channelID == id })
                        .map({ $0.value })
                    {
                        guard !Task.isCancelled else { return }
                        await channel.updateConnectionStatus(connectionStatus)
                    }
                }
                
                // Receive data
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await data in self.dataToChannelAsyncSequence
                        .filter({ $0.channelID == id })
                        .map({ $0.value })
                    {
                        guard !Task.isCancelled else { return }
                        await channel.received(data: data)
                    }
                }
            }
            
      
        }
        try await channels.insert(.init(element: channel, task: task))
        return channel
 
    }
}

// MARK: Channel
public extension PeerConnection {
    
    func newChannel(
        id: DataChannelID,
        config: DataChannelConfig
    ) async throws -> Channel {
        try await channels.assertUnique(id: id)
        
        // This will trigger `shouldNegotiate`
        guard let dataChannel = peerConnection.dataChannel(
            forLabel: id.label,
            configuration: config.rtc(dataChannelID: id)
        ) else {
            throw Error.failedToCreateDataChannel
        }

        //assert(dataChannel.channelId == id.id, "Expected channelId to be: \(id.id), but was: \(dataChannel.channelId), streamID was: \(dataChannel.streamId)")
        return try await add(id: id, dataChannel: dataChannel)
    }
}

// MARK: Disconnecting
public extension PeerConnection {
    func disconnect() async {
        await channels.cancelDisconnectAndRemoveAll()
        peerConnection.close()
        peerConnection.delegate = nil
    }
}

// MARK: Negotiation
public extension PeerConnection {
    
    func offer() async throws -> Offer {
        let localSDP = try await peerConnection.offer(for: Self.negotiationConstraints)
        try await peerConnection.setLocalDescription(localSDP)
        return Offer(sdp: localSDP.sdp)
    }
    
    func answer() async throws -> Answer {
        let localSDP = try await peerConnection.answer(for: Self.negotiationConstraints)
        try await peerConnection.setLocalDescription(localSDP)
        return Answer(sdp: localSDP.sdp)
    }
    
    func setRemoteOffer(_ offer: Offer) async throws {
        let sdp = offer.rtc()
        try await peerConnection.setRemoteDescription(sdp)
    }
    
    func setRemoteAnswer(_ answer: Answer) async throws {
        let sdp = answer.rtc()
        try await peerConnection.setRemoteDescription(sdp)
    }
    
    func addRemoteICE(_ ice: ICECandidate) async throws {
        let iceCandidate = ice.rtc()
        try await withCheckedThrowingContinuation { [unowned self] (continuation: CheckedContinuation<Void, Swift.Error>) in
            self.peerConnection.add(iceCandidate) { maybeError in
                if let error = maybeError {
                    let nsError = error as NSError
                    if nsError.domain == "org.webrtc.RTC_OBJC_TYPE(RTCPeerConnection)" && nsError.code == 6 && (nsError.userInfo[NSLocalizedDescriptionKey] as? NSString) == "The remote description was null" {
                        print("\n\n⚠️⚠️⚠️ WARNING SUPRESSED ERROR ⚠️⚠️⚠️:\n `\(error.localizedDescription)`\n⚠️⚠️⚠️⚠️⚠️⚠️\n")
                        continuation.resume(returning: ())
                    } else {
                        debugPrint("Failed to set ICE: \(String(describing: error))")
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    func removeICECandidates(_ ices: [ICECandidate]) {
        let iceCandidates = ices.map { $0.rtc() }
        peerConnection.remove(iceCandidates)
    }
}

// MARK: RTCPeerConnectionDelegate
public extension PeerConnection {
    func addDataChannelIfNeeded(_ dataChannel: RTCDataChannel) {
        let id = DataChannelID(label: dataChannel.label)
        Task {
            guard await channels.containsID(id) == false else {
                return
            }
            try! await add(id: id, dataChannel: dataChannel)
        }
        
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didOpen dataChannel:\(dataChannel.channelId)")
        addDataChannelIfNeeded(dataChannel)
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), should Negotiate")
        shouldNegotiateAsyncContinuation.yield(negotiationRole)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        let state = stateChanged.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didChange SignalingState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let state = newState.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didChange IceConnectionState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didRemove stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didAdd stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let state = newState.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didChange IceGatheringState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let iceCandidate = candidate.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didGenerate ICE")
        generatedICECandidateAsyncContinutation.yield(iceCandidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didRemove #\(candidates.count) ICE candidates")
        let iceCandidate = candidates.map { $0.swiftify() }
        removeICECandidatesAsyncContinutation.yield(iceCandidate)
    }
    
}

// MARK: RTCDataChannelDelegate
public extension PeerConnection {
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), dataChannel=\(dataChannel.channelId) didReceiveMessageWith #\(buffer.data.count) bytes")
        let id = DataChannelID(label: dataChannel.label)
        dataToChannelAsyncContinuation.yield(.init(buffer.data, channelID: id))
    }
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let readyState = dataChannel.readyState.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), dataChannel=\(dataChannel.channelId) dataChannelDidChangeState to: \(readyState)")
        let id = DataChannelID(label: dataChannel.label)
        self.connectionStatusToChannelAsyncContinuation.yield(.init(readyState, channelID: id))
    }
}
