// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Indxe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Indxe", targets: ["Indxe"])
    ],
    targets: [
        .executableTarget(
            name: "Indxe",
            path: "Sources/Indxe"
        ),
        .testTarget(
            name: "IndxeTests",
            dependencies: ["Indxe"],
            path: "Sources/IndxeTests"
        )
    ]
)