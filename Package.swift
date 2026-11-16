// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Swatchbook",
    platforms: [
        .macOS(.v13)   // Deployment target: macOS 13 Ventura
    ],
    targets: [
        .executableTarget(
            name: "Swatchbook",
            path: "Sources/Swatchbook"
        )
    ]
)
