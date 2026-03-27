// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iTunesKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "iTunesKit",
            targets: ["iTunesKit"]
        ),
        .executable(
            name: "FetchNokia",
            targets: ["FetchNokia"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "iTunesKit",
            path: "Sources",
            exclude: ["iTunesKit/Examples"]
        ),
        .executableTarget(
            name: "FetchNokia",
            dependencies: ["iTunesKit"],
            path: "Sources/iTunesKit/Examples"
        ),
        .testTarget(
            name: "iTunesKitTests",
            dependencies: ["iTunesKit"]
        ),
    ]
)
