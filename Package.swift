// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PoPHelper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PoPHelper",
            path: "PoPHelper",
            exclude: ["Resources/README.md"],
            sources: ["Sources"],
            resources: [.copy("Resources/tweaks.json")]
        ),
        // No XCTest target: the dev machine has Command Line Tools only (no Xcode),
        // so tests run as an in-process self-test — `swift run PoPHelper --self-test`.
    ]
)
