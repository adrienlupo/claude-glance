// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeGlance",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeGlance",
            path: "Sources"
        )
    ]
)
