// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhistFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WhistFlow", targets: ["WhistFlow"])
    ],
    targets: [
        .executableTarget(
            name: "WhistFlow",
            path: "Sources"
        )
    ]
)
