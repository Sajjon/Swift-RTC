// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-rtc",
    products: [
        .library(name: "RTCClient", targets: ["RTCClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC", from: "108.0.0"),
    ],
    targets: [
        .target(
            name: "RTCModels",
            dependencies: [],
            path: "Sources/Models"
        ),
        .target(
            name: "RTCPeerConnection",
            dependencies: [
                "RTCModels",
                "WebRTC"
            ],
            path: "Sources/PeerConnection"
        ),
        .testTarget(
            name: "PeerConnectionTests",
            dependencies: [
                "RTCPeerConnection"
            ]
        ),
        .target(
            name: "RTCSignaling",
            dependencies: ["RTCModels"],
            path: "Sources/Signaling"
        ),
        .target(
            name: "RTCClient",
            dependencies: [
                "RTCSignaling",
                "RTCPeerConnection",
            ],
            path: "Sources/Client"
        )
    ]
)
