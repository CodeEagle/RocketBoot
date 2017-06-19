// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription

let package = Package(
    name: "RocketBoot",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Boot",
            targets: ["Boot"]),
        .executable(name: "RocketBoot", targets: ["RocketBoot"]),
    ],
    dependencies: [
        .package(url: "git@github.com:behrang/YamlSwift.git", from: Version(3,4,0)),
        .package(url: "git@github.com:mtynior/ColorizeSwift.git", from: Version(1,1,0)),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Boot",
            dependencies: ["Yaml", "ColorizeSwift"]),
        .testTarget(
            name: "BootTests",
            dependencies: ["Boot", "Yaml", "ColorizeSwift"],
            sources: [".", "./Resources/*"]),
        .target(
            name: "RocketBoot",
            dependencies: ["Boot", "Yaml", "ColorizeSwift"])
    ]
)
