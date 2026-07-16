// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PhotoAnalysisKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "PhotoAnalysisKit",
            targets: ["PhotoAnalysisKit"]
        )
    ],
    targets: [
        .target(
            name: "PhotoAnalysisKit",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .testTarget(
            name: "PhotoAnalysisKitTests",
            dependencies: ["PhotoAnalysisKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
