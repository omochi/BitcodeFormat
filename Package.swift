// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "BitcodeFormat",
    platforms: [.macOS(.v10_11)],
    products: [
        .library(name: "BitcodeFormat", targets: ["BitcodeFormat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "4.0.0")
    ],
    targets: [
        .target(name: "BitcodeFormat", dependencies: ["BigInt"]),
        .testTarget(name: "BitcodeFormatTests", dependencies: ["BitcodeFormat"]),
    ]
)
