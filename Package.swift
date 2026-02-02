// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "apple-plugin-inbox",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "MoEngagePluginInbox", targets: ["MoEngagePluginInbox"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/moengage/apple-sdk.git", exact: "10.10.0"),
        .package(url: "https://github.com/moengage/iOS-PluginBase.git", exact: "6.8.0"),
        // For development
        // .package(path: "../iOS-PluginBase")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.

        .target(
            name: "MoEngagePluginInbox",
            dependencies: [
                .product(name: "MoEngagePluginBase", package: "iOS-PluginBase"),
                .product(name: "MoEngageInbox", package: "apple-sdk")
            ],
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("Foundation")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
