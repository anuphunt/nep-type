// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LekhaPortableCore",
    products: [
        .library(name: "LekhaPortableCore", targets: ["LekhaPortableCore"]),
        .executable(name: "lekha-conformance", targets: ["lekha-conformance"])
    ],
    targets: [
        .target(name: "LekhaPortableCore"),
        .executableTarget(name: "lekha-conformance", dependencies: ["LekhaPortableCore"])
    ]
)
