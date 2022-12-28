//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
public struct ICECandidate: Sendable, Hashable, Codable {
   
    public let sdp: String
    public let sdpMLineIndex: Int32
    public let sdpMid: String?
    
    public init(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        self.sdp = sdp
        self.sdpMLineIndex = sdpMLineIndex
        self.sdpMid = sdpMid
    }
}
