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
            RTCIceServer(urlStrings: [$0])
        }
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        return config
    }
}
