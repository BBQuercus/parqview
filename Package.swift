// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParqView",
    platforms: [
        .macOS(.v13) // macOS Ventura minimum for modern SwiftUI features
    ],
    products: [
        // Main application executable
        .executable(
            name: "ParqViewApp",
            targets: ["ParqViewApp"]
        ),
        // Test reader executable
        .executable(
            name: "TestReader",
            targets: ["TestReader"]
        ),
        // Test file opening
        .executable(
            name: "TestFileOpening",
            targets: ["TestFileOpening"]
        ),
        // Shared framework for common functionality
        .library(
            name: "SharedCore",
            targets: ["SharedCore"]
        )
    ],
    dependencies: [
        // We'll add DuckDB and other dependencies here later
        // For now, keeping it simple to get the structure right
    ],
    targets: [
        // Main application target
        .executableTarget(
            name: "ParqViewApp",
            dependencies: ["SharedCore", "CParquetReader"],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        
        // C++ Parquet Reader
        .target(
            name: "CParquetReader",
            path: "Sources/SharedCore",
            sources: ["cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags([
                    "-std=c++17",
                    "-I/opt/homebrew/include",
                    "-I/usr/local/include"
                ])
            ],
            linkerSettings: [
                .linkedLibrary("arrow"),
                .linkedLibrary("parquet"),
                .linkedLibrary("c++"),
                .unsafeFlags([
                    "-L/opt/homebrew/lib",
                    "-L/usr/local/lib"
                ])
            ]
        ),
        
        // Shared core functionality
        .target(
            name: "SharedCore",
            dependencies: ["CParquetReader"],
            path: "Sources/SharedCore",
            exclude: ["Scripts", "cpp"],
            sources: ["Bridge", "Models", "Services"]
        ),
        
        // Test reader executable
        .executableTarget(
            name: "TestReader",
            dependencies: ["SharedCore", "CParquetReader"]
        ),
        
        // Test file opening app
        .executableTarget(
            name: "TestFileOpening",
            dependencies: ["SharedCore"]
        ),
        
        // Test targets
        .testTarget(
            name: "SharedCoreTests",
            dependencies: ["SharedCore"]
        ),
        .testTarget(
            name: "ParqViewAppTests",
            dependencies: ["ParqViewApp"]
        )
    ]
)