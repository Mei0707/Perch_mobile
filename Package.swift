// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Perch",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Perch", targets: ["PerchApp"])
    ],
    targets: [
        .target(
            name: "Perch",
            path: "Sources/Perch"
        ),
        .executableTarget(
            name: "PerchApp",
            dependencies: ["Perch"],
            path: "Sources/PerchApp"
        ),
        .testTarget(
            name: "PerchTests",
            dependencies: ["Perch"],
            path: "Tests/PerchTests"
        )
    ]
)
