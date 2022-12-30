//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import RTCModels

extension WebRTCConfig {
    func rtc() -> RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = self.iceServers.map {
            $0.rtc()
        }
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        return config
    }
}

extension ICEServer {
    func rtc() -> RTCIceServer {
        guard let login else {
            return .init(urlStrings: [serverURL])
        }
        return .init(urlStrings: [serverURL], username: login.username, credential: login.credential)
    }
}
