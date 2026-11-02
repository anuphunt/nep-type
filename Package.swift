// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NepType",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NepType", targets: ["NepaliKeyboard"]), .executable(name: "NepTypeInput", targets: ["NepTypeInput"])],
    targets: [
        .target(name: "NepaliCore"),
        .executableTarget(name: "NepaliKeyboard", dependencies: ["NepaliCore"]),
        .executableTarget(name: "NepTypeInput", dependencies: ["NepaliCore"]),
        .testTarget(name: "NepaliCoreTests", dependencies: ["NepaliCore"])
    ]
)
