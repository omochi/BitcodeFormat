// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "BitCodeFormat",
    platforms: [.macOS(.v10_11)],
    products: [
        .library(name: "BitCodeFormat", targets: ["BitCodeFormat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "4.0.0")
    ],
    targets: [
        .target(name: "BitCodeFormat", dependencies: ["BigInt"]),
        .testTarget(name: "BitCodeFormatTests", dependencies: ["BitCodeFormat"]),
    ]
)
