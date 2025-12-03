// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DDMmacOSUpdateReminder",
    platforms: [
        .macOS(.v12)  // Minimum macOS 12 Monterey for os.Logger
    ],
    products: [
        .executable(
            name: "DDMmacOSUpdateReminder",
            targets: ["DDMNotifier"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DDMNotifier",
            path: "DDMNotifier/Sources",
            sources: [
                "main.swift",
                "Logger.swift",
                "Configuration/Configuration.swift",
                "DDMParser/DDMParser.swift",
                "DeferralManager/DeferralManager.swift",
                "DialogController/DialogController.swift",
                "HealthReporter/HealthReporter.swift",
                "LaunchDaemonManager/LaunchDaemonManager.swift"
            ]
        ),
        .testTarget(
            name: "DDMNotifierTests",
            dependencies: ["DDMNotifier"],
            path: "Tests/DDMNotifierTests"
        )
    ]
)
