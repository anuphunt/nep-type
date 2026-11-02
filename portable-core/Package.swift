// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NepTypePortableCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "NepTypePortableCore", targets: ["NepTypePortableCore"]),
        .executable(name: "neptype-conformance", targets: ["neptype-conformance"])
    ],
    dependencies: [.package(name: "NepType", path: "..")],
    targets: [
        .target(name: "NepTypePortableCore", dependencies: [.product(name: "NepaliCore", package: "NepType")]),
        .executableTarget(name: "neptype-conformance", dependencies: ["NepTypePortableCore"])
    ]
)
