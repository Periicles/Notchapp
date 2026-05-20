// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "NotchBar",
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
            path: "Sources"
        ),
        .testTarget(
            name: "NotchBarTests",
            dependencies: ["NotchBar"],
            path: "Tests/NotchBarTests"
        ),
    ]
)
