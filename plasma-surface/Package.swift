// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlasmaSurface",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PlasmaSurface",
            path: "Sources/PlasmaSurface",
            exclude: ["Resources"]
        ),
    ]
)
