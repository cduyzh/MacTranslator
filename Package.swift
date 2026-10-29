// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cduyzhTranslator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "cduyzhTranslator",
            targets: ["cduyzhTranslator"]
        ),
        .library(
            name: "cduyzhTranslatorCore",
            targets: ["cduyzhTranslatorCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "cduyzhTranslatorCore",
            dependencies: [],
            path: "Sources/cduyzhTranslatorCore"
        ),
        .executableTarget(
            name: "cduyzhTranslator",
            dependencies: ["cduyzhTranslatorCore"],
            path: "Sources/cduyzhTranslatorApp"
        ),
        .testTarget(
            name: "cduyzhTranslatorTests",
            dependencies: ["cduyzhTranslatorCore"],
            path: "Tests/cduyzhTranslatorTests"
        )
    ]
)
