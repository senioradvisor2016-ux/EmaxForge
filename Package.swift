// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Emulotion",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EmaxForge", targets: ["EmaxForge"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        // Main GUI app
        .executableTarget(
            name: "EmaxForge",
            path: "EmaxForge/Sources",
            exclude: ["CLI"],
            resources: [
                .copy("../Resources/AppIcon.icns"),
                .copy("../Resources/Info.plist")
            ]
        ),
        
        // Tests
        .testTarget(
            name: "EmaxForgeTests",
            dependencies: ["EmaxForge"],
            path: "Tests/EmaxForgeTests"
        )
    ]
)
