// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Twenty",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Twenty",
            path: "Sources/Twenty"
        ),
        .testTarget(
            name: "TwentyTests",
            dependencies: ["Twenty"]
        )
    ]
)
