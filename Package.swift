// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FlowBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowBar", targets: ["FlowBar"])
    ],
    targets: [
        .executableTarget(
            name: "FlowBar",
            path: "Sources/FlowBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "FlowBarTests",
            dependencies: ["FlowBar"],
            path: "Tests/FlowBarTests"
        )
    ]
)
