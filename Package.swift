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
            name: "Linter Rule SQL",
            targets: ["Linter Rule SQL"]
        ),

        .library(
            name: "Linter Rule SwiftUI",
            targets: ["Linter Rule SwiftUI"]
        ),

        .library(
            name: "Linter Rule Feature",
            targets: ["Linter Rule Feature"]
        ),

        .library(
            name: "Linter Rule Build Errors",
            targets: ["Linter Rule Build Errors"]
        ),

        .executable(
            name: "swift-linter-build-errors",
            targets: ["Linter Build Errors"]
        ),

        .plugin(
            name: "Linter Build Errors Plugin",
            targets: ["Linter Build Errors Plugin"]
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
    traits: [
        .trait(
            name: "LinterRuleBuildErrors",
            description: "Linter Rule Build Errors and the dependencies only it needs"
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-lint.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-cardinal",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-atoms/swift-byte", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "604.0.0"..<"605.0.0"),
    ],
    targets: [

        .target(
            name: "Linter Rule ResultBuilder",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Structure",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "Cardinal", package: "swift-cardinal"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Memory",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Testing",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Idiom",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Suppression",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Package",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Rule Scope"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Scope",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule SQL",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Rule Scope"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule SwiftUI",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Rule Scope"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rule Feature",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Rule Scope"),
                .target(name: "Linter Rule SwiftUI"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "Linter Rules",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Rule Idiom"),
                .target(name: "Linter Rule Memory"),
                .target(name: "Linter Rule Package"),
                .target(name: "Linter Rule ResultBuilder"),
                .target(name: "Linter Rule Structure"),
                .target(name: "Linter Rule Suppression"),
                .target(name: "Linter Rule Testing"),
            ]
        ),

        .target(
            name: "Linter Rule Build Errors",
            dependencies: [
                .product(name: "Byte", package: "swift-byte", condition: .when(traits: ["LinterRuleBuildErrors"])),
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Rule Scope"),
                .target(name: "Linter Rule SQL"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .executableTarget(
            name: "Linter Build Errors",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Rule Build Errors"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),

        .plugin(
            name: "Linter Build Errors Plugin",
            capability: .buildTool(),
            dependencies: [
                .target(name: "Linter Build Errors")
            ],
            path: "Sources/Linter Build Errors Plugin"
        ),

        .target(
            name: "Linter Rules Test Support",
            dependencies: [

                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Lint Test Support", package: "swift-lint"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Tests/Support"
        ),

        .testTarget(
            name: "Linter Rule ResultBuilder Tests",
            dependencies: [
                .target(name: "Linter Rule ResultBuilder"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Structure Tests",
            dependencies: [
                .target(name: "Linter Rule Structure"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Memory Tests",
            dependencies: [
                .target(name: "Linter Rule Memory"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Testing Tests",
            dependencies: [
                .target(name: "Linter Rule Testing"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Idiom Tests",
            dependencies: [
                .target(name: "Linter Rule Idiom"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Package Tests",
            dependencies: [
                .target(name: "Linter Rule Package"),
                .target(name: "Linter Rule Scope"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule SQL Tests",
            dependencies: [
                .target(name: "Linter Rule SQL"),
                .target(name: "Linter Rule Scope"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule SwiftUI Tests",
            dependencies: [
                .target(name: "Linter Rule SwiftUI"),
                .target(name: "Linter Rule Scope"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Feature Tests",
            dependencies: [
                .target(name: "Linter Rule Feature"),
                .target(name: "Linter Rule Scope"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Suppression Tests",
            dependencies: [
                .target(name: "Linter Rule Suppression"),
                .target(name: "Linter Rules Test Support"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "Linter Rule Build Errors Tests",
            dependencies: [
                .target(name: "Linter Rule Build Errors"),
                .target(name: "Linter Rules Test Support"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
