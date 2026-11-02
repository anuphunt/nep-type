// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lekha",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Lekha", targets: ["NepaliKeyboard"]), .executable(name: "LekhaInput", targets: ["LekhaInput"])],
    targets: [
        .target(name: "NepaliCore"),
        .executableTarget(name: "NepaliKeyboard", dependencies: ["NepaliCore"]),
        .executableTarget(name: "LekhaInput", dependencies: ["NepaliCore"]),
        .testTarget(name: "NepaliCoreTests", dependencies: ["NepaliCore"])
    ]
)
