//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import Foundation
import WebRTC

extension RTCDataChannel: @unchecked Sendable {}
extension RTCIceCandidate: @unchecked Sendable {}
extension RTCSessionDescription: @unchecked Sendable {}
extension RTCPeerConnection: @unchecked Sendable {}
extension RTCMediaConstraints: @unchecked Sendable {}

