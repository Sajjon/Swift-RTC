// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let develop = true

let targets: [Target] = [
    .target(
        name: "RTCModels",
        dependencies: [
            "AsyncExtensions",
            .product(name: "Tagged", package: "swift-tagged"),
            .product(name: "Collections", package: "swift-collections"),
        ],
        path: "Sources/Models"
    ),
    .target(
        name: "RTCPeerConnection",
        dependencies: [
            "RTCModels",
            "WebRTC",
        ],
        path: "Sources/PeerConnection"
    ),
    .target(
        name: "RTCPeerConnectionTestSupport",
        dependencies: [
            "RTCPeerConnection",
            "RTCSignaling",
            "RTCModels",
        ],
        path: "Sources/PeerConnectionTestSupport"
    ),
    .testTarget(
        name: "PeerConnectionTests",
        dependencies: [
            "RTCPeerConnection",
            "RTCPeerConnectionTestSupport",
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
            "RTCPeerConnectionTestSupport",
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
        .package(url: "https://github.com/sideeffect-io/AsyncExtensions", from: "0.5.1"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.4"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.9.0"),
    ],
    targets: targets
)
