// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NepTypePortableCore",
    products: [
        .library(name: "NepTypePortableCore", targets: ["NepTypePortableCore"]),
        .executable(name: "neptype-conformance", targets: ["neptype-conformance"])
    ],
    targets: [
        .target(name: "NepTypePortableCore"),
        .executableTarget(name: "neptype-conformance", dependencies: ["NepTypePortableCore"])
    ]
)
