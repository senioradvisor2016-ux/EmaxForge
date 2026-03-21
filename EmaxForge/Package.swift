// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EmaxForge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "EmaxForge",
            targets: ["EmaxForgeApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EmaxForgeApp",
            path: "Sources",
            exclude: [
                "CLI"  // Exclude CLI code for GUI build
            ],
            resources: [
                .copy("../Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .define("GUI_BUILD")
            ]
        )
    ]
)
