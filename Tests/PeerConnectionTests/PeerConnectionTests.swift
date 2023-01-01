import XCTest
import RTCPeerConnectionTestSupport
@testable import RTCPeerConnection
import RTCModels

final class RTCPeerConnectionTests: XCTestCase {

    
    func test_assert_that_creating_new_datachannel_triggers_ShouldNegotiate_event() async throws {
        
        let pc0NegotiationTriggered = expectation(description: "PeerConnection 0 triggered negotiateion")
        let pc1NegotiationTriggered = expectation(description: "PeerConnection 1 triggered negotiateion")
        
        let pcID: PeerConnectionID = 0
        let initiator = try PeerConnection(
            id: pcID,
            config: .default,
            negotiationRole: .initiator
        )
        
        let answerer = try PeerConnection(
            id: pcID,
            config: .default,
            negotiationRole: .answerer
        )
     
        Task {
            for await _ in initiator.shouldNegotiateAsyncSequence.prefix(1) {
                pc0NegotiationTriggered.fulfill()
            }
        }
        
        Task {
            for await _ in answerer.shouldNegotiateAsyncSequence.prefix(1) {
                pc1NegotiationTriggered.fulfill()
            }
        }
        
        
        let channelID: DataChannelID = 0
        let channelConfig: DataChannelConfig = .default
        _ = try await initiator.newChannel(id: channelID, config: channelConfig)
        _ = try await answerer.newChannel(id: channelID, config: channelConfig)
        
        await waitForExpectations(timeout: 3)
        
    }
    
}
