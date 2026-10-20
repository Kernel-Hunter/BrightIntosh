// swift-tools-version: 5.9
//
// Swift package used only to unit test the pure brightness model with
// `swift test`. The app itself is built with BrightIntosh.xcodeproj.

import PackageDescription

let package = Package(
    name: "BrightnessCurve",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BrightnessCurve", targets: ["BrightnessCurve"])
    ],
    targets: [
        .target(
            name: "BrightnessCurve",
            path: "BrightIntosh",
            sources: ["BrightnessCurve.swift"]
        ),
        .testTarget(
            name: "BrightnessCurveTests",
            dependencies: ["BrightnessCurve"],
            path: "Tests/BrightnessCurveTests"
        )
    ]
)
