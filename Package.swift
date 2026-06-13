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
        .testTarget(
            name: "PoPHelperTests",
            dependencies: ["PoPHelper"],
            path: "Tests/PoPHelperTests"
        ),
    ]
)
