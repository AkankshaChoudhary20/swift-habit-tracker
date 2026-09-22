// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HabitTrackerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "HabitTrackerCore",
            targets: ["HabitTrackerCore"]
        )
    ],
    targets: [
        .target(
            name: "HabitTrackerCore",
            path: "Sources/HabitTrackerCore"
        ),
        .testTarget(
            name: "HabitTrackerCoreTests",
            dependencies: ["HabitTrackerCore"],
            path: "Tests/HabitTrackerCoreTests"
        )
    ]
)
