// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatsBar",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "StatsBarCore", targets: ["StatsBarCore"]),
        .executable(name: "StatsBar", targets: ["StatsBar"])
    ],
    targets: [
        .target(
            name: "StatsBarCore"
        ),
        .executableTarget(
            name: "StatsBar",
            dependencies: ["StatsBarCore"]
        ),
        .testTarget(
            name: "StatsBarTests",
            dependencies: ["StatsBarCore"]
        )
    ]
)
