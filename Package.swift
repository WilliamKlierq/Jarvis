// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jarvis", targets: ["Jarvis"])
    ],
    targets: [
        .executableTarget(
            name: "Jarvis",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
