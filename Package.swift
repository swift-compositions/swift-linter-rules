// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-linter-rules",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Linter Rule ResultBuilder",
            targets: ["Linter Rule ResultBuilder"]
        ),

        .library(
            name: "Linter Rule Structure",
            targets: ["Linter Rule Structure"]
        ),

        .library(
            name: "Linter Rule Memory",
            targets: ["Linter Rule Memory"]
        ),

        .library(
            name: "Linter Rule Testing",
            targets: ["Linter Rule Testing"]
        ),

        .library(
            name: "Linter Rule Idiom",
            targets: ["Linter Rule Idiom"]
        ),

        .library(
            name: "Linter Rule Suppression",
            targets: ["Linter Rule Suppression"]
        ),

        .library(
            name: "Linter Rule Package",
            targets: ["Linter Rule Package"]
        ),

        .library(
            name: "Linter Rules Test Support",
            targets: ["Linter Rules Test Support"]
        ),

        .library(
            name: "Linter Rules",
            targets: ["Linter Rules"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-linter-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cardinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-byte-primitives.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    ],
    targets: [

        .target(
            name: "Linter Rule ResultBuilder",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Structure",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Memory",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Testing",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Idiom",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Suppression",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Package",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rules",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                "Linter Rule Idiom",
                "Linter Rule Memory",
                "Linter Rule Package",
                "Linter Rule ResultBuilder",
                "Linter Rule Structure",
                "Linter Rule Suppression",
                "Linter Rule Testing",
            ]
        ),

        .target(
            name: "Linter Rules Test Support",
            dependencies: [

                .product(name: "Linter Primitives Test Support", package: "swift-linter-primitives"),
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Tests/Support"
        ),

        .testTarget(
            name: "Linter Rule ResultBuilder Tests",
            dependencies: [
                "Linter Rule ResultBuilder",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Structure Tests",
            dependencies: [
                "Linter Rule Structure",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Memory Tests",
            dependencies: [
                "Linter Rule Memory",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Testing Tests",
            dependencies: [
                "Linter Rule Testing",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Idiom Tests",
            dependencies: [
                "Linter Rule Idiom",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Package Tests",
            dependencies: [
                "Linter Rule Package",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Suppression Tests",
            dependencies: [
                "Linter Rule Suppression",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
