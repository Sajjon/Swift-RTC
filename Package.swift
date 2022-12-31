// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let develop = true

let targets: [Target] = [
    .target(
        name: "RTCModels",
        dependencies: ["AsyncExtensions"],
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
        dependencies: [
            "AsyncExtensions",
            "RTCModels",
        ],
        path: "Sources/Signaling"
    ),
    .target(
        name: "RTCClient",
        dependencies: [
            "RTCSignaling",
            "RTCPeerConnection",
        ],
        path: "Sources/Client"
    ),
    .testTarget(
        name: "RTCClientTests",
        dependencies: [
            "RTCClient",
        ]
    )
]


if develop {
    targets.forEach {
        $0.swiftSettings = [
            .unsafeFlags([
                "-Xfrontend", "-warn-concurrency",
                "-Xfrontend", "-enable-actor-data-race-checks"
            ])
        ]
        
    }
}

let package = Package(
    name: "swift-rtc",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "RTCClient", targets: ["RTCClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC", from: "108.0.0"),
        .package(url: "https://github.com/sideeffect-io/AsyncExtensions", from: "0.5.1")
    ],
    targets: targets
)
