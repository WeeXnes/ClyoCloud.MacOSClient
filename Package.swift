// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "ClyoMacClient",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ClyoMacClient",
            targets: ["ClyoMacClient"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ClyoMacClient",
            dependencies: [],
            path: "Sources/ClyoMacClient"
        )
    ]
)
