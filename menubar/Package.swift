// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OffYet",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "OffYetCore"),
        .executableTarget(name: "OffYetApp", dependencies: ["OffYetCore"]),
        .testTarget(name: "OffYetCoreTests", dependencies: ["OffYetCore"]),
    ]
)
