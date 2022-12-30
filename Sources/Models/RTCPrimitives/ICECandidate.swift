//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
public struct ICECandidate: Sendable, Hashable, Codable, CustomStringConvertible {
   
    public let sdp: String
    public let sdpMLineIndex: Int32
    public let sdpMid: String?
    public let serverUrl: String?
    
    public init(sdp: String, sdpMLineIndex: Int32, sdpMid: String?, serverUrl: String?) {
        self.sdp = sdp
        self.sdpMLineIndex = sdpMLineIndex
        self.sdpMid = sdpMid
        self.serverUrl = serverUrl
    }
}

public extension ICECandidate {
    var description: String {
        "sdpMLineIndex: \(sdpMLineIndex), sdpMid: \(String(describing: sdpMid)), serverUrl: \(String(describing: serverUrl)), sdp: \(sdp)"
    }
}
