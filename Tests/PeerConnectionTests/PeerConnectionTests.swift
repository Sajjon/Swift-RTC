import XCTest
@testable import RTCPeerConnection
import RTCModels

final class RTCPeerConnectionTests: XCTestCase {

    
    func test_assert_that_creating_new_datachannel_triggers_ShouldNegotiate_event() async throws {
        
        let pc0NegotiationTriggered = expectation(description: "PeerConnection 0 triggered negotiateion")
        let pc1NegotiationTriggered = expectation(description: "PeerConnection 1 triggered negotiateion")
        
        let pc0 = try PeerConnection(id: 0, config: .init(isInitator: true))
        let pc1 = try PeerConnection(id: 1, config: .init(isInitator: false))
     
        Task {
            for await _ in pc0.shouldNegotiateAsyncSequence.prefix(1) {
                pc0NegotiationTriggered.fulfill()
            }
        }
        
        Task {
            for await _ in pc1.shouldNegotiateAsyncSequence.prefix(1) {
                pc1NegotiationTriggered.fulfill()
            }
        }
        
        
        let channelID: DataChannelID = 0
        let channelConfig: DataChannelConfig = .default
        try await pc0.newChannel(id: channelID, config: channelConfig)
        try await pc1.newChannel(id: channelID, config: channelConfig)
        
        await waitForExpectations(timeout: 3)
        
    }
}
