// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Specter",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "SpecterCore", targets: ["SpecterCore"]),
        .executable(name: "Specter", targets: ["Specter"])
    ],
    targets: [
        .target(
            name: "SpecterCore"
        ),
        .executableTarget(
            name: "Specter",
            dependencies: ["SpecterCore"]
        ),
        .testTarget(
            name: "SpecterTests",
            dependencies: ["SpecterCore"]
        )
    ]
)
