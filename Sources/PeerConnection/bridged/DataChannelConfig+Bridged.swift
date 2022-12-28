//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import RTCModels

extension DataChannelConfig {
    func rtc() -> RTCDataChannelConfiguration {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = isOrdered
        config.isNegotiated = isNegotiated
        return config
    }
}
