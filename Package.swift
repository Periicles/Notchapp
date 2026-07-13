// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "NotchBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "NotchBar",
            targets: ["NotchBar"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "NotchBar",
            path: "Sources",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NotchBarTests",
            dependencies: ["NotchBar"],
            path: "Tests/NotchBarTests"
        ),
    ]
)
