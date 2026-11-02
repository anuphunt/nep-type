// swift-tools-version: 6.0
import PackageDescription
import Foundation
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let rustLibrary = ProcessInfo.processInfo.environment["NEPTYPE_RUST_LIBRARY"] ?? root + "/engine/target/release/libneptype_engine.a"

let package = Package(
    name: "NepType",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "NepaliCore", targets: ["NepaliCore"]), .executable(name: "NepType", targets: ["NepaliKeyboard"]), .executable(name: "NepTypeInput", targets: ["NepTypeInput"])],
    targets: [
        .systemLibrary(name: "CNepTypeEngine", path: "shared/include"),
        .target(name: "NepaliCore", dependencies: ["CNepTypeEngine"], linkerSettings: [.unsafeFlags([rustLibrary])]),
        .executableTarget(name: "NepaliKeyboard", dependencies: ["NepaliCore"]),
        .executableTarget(name: "NepTypeInput", dependencies: ["NepaliCore"]),
        .testTarget(name: "NepaliCoreTests", dependencies: ["NepaliCore"])
    ]
)
