// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacNAS",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "Shared",
            path: "Shared",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        .executableTarget(
            name: "MacNAS",
            dependencies: ["Shared"],
            path: "MacNAS",
            exclude: ["Info.plist", "Resources/AppIcon.icns"],
            resources: [.copy("Resources/love.gif")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        .executableTarget(
            name: "com.macnas.helper",
            dependencies: ["Shared"],
            path: "com.macnas.helper",
            exclude: ["com.macnas.helper.plist"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
