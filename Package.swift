// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let develop = true

let targets: [Target] = [
    .target(
        name: "P2PModels",
        dependencies: [
            "AsyncExtensions",
            .product(name: "Bite", package: "Bite"),
            .product(name: "Tagged", package: "swift-tagged"),
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "SwiftLogConsoleColors", package: "swift-log-console-colors"),
        ],
        path: "Sources/Models"
    ),
    .target(
        name: "P2PPeerConnection",
        dependencies: [
            "P2PModels",
            "WebRTC",
            "Tunnel",
        ],
        path: "Sources/PeerConnection"
    ),
    .testTarget(
        name: "PeerConnectionTests",
        dependencies: [
            "P2PPeerConnection",
            "SignalingServerRadixTestSupport",
        ]
    ),
    .target(
        name: "SignalingServerClient",
        dependencies: [
            "AsyncExtensions",
            "P2PModels",
        ],
        path: "Sources/Signaling/SignalingServerClient"
    ),
    .target(
        name: "Tunnel",
        dependencies: [
            "P2PModels",
            "AsyncExtensions",
        ]
    ),
    .target(
        name: "WebSocket",
        dependencies: [
            "SignalingServerClient",
        ],
        path: "Sources/Signaling/WebSocket"
    ),
     .target(
        name: "MessageAssembler",
        dependencies: [
            "P2PModels",
        ],
        path: "Sources/Signaling/MessageAssembler"
    ),
          .target(
        name: "MessageSplitter",
        dependencies: [
            "P2PModels",
            .product(name: "Algorithms", package: "swift-algorithms"),
        ],
        path: "Sources/Signaling/MessageSplitter"
    ),
    .target(
        name: "SignalingServerRadix",
        dependencies: [
            "MessageAssembler",
            "MessageSplitter",
            "WebSocket",
            "Tunnel",
        ],
        path: "Sources/Signaling/SignalingServerRadix"
    ),
      .target(
        name: "SignalingServerRadixTestSupport",
        dependencies: [
            "SignalingServerRadix",
        ],
        path: "Sources/Signaling/SignalingServerRadixTestSupport"
    ),
    .testTarget(
        name: "AssembleSplitMessageTests",
        dependencies: [
            "MessageSplitter",
            "MessageAssembler",
        ]
    ),
    .target(
        name: "P2PClient",
        dependencies: [
            "P2PPeerConnection",
            "SignalingServerClient",
            "Tunnel",
        ],
        path: "Sources/Client"
    ),
    .testTarget(
        name: "P2PClientTests",
        dependencies: [
            "P2PClient",
            "SignalingServerRadixTestSupport"
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
    name: "Converse",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "P2PClient", targets: ["P2PClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC", from: "108.0.0"),
        
        // RDX Works
        // We use SSH because repos are private...
        .package(url: "git@github.com:radixdlt/Bite.git", from: "0.0.4"),
        
        .package(url: "https://github.com/sideeffect-io/AsyncExtensions", from: "0.5.2"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.4"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.9.0"),
        .package(url: "https://github.com/nneuberger1/swift-log-console-colors", from: "1.0.3"),
    ],
    targets: targets
)
