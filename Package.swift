// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "shade",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "shade",
            path: "Sources/shade"
        )
    ]
)
