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
    func rtc(dataChannelID: DataChannelID) -> RTCDataChannelConfiguration {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = isOrdered
        config.isNegotiated = isNegotiated
        config.channelId = dataChannelID.id
        return config
    }
}
