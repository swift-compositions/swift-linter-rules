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
    .package(
      url: "https://github.com/swift-molecules/swift-linter.git", branch: "main"),
    .package(
      url: "https://github.com/swift-molecules/swift-cardinal.git", branch: "main"),
    .package(url: "https://github.com/swift-molecules/swift-byte.git", branch: "main"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
  ],
  targets: [

    .target(
      name: "Linter Rule ResultBuilder",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),

    .target(
      name: "Linter Rule Structure",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
        .product(name: "Cardinal", package: "swift-cardinal"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),

    .target(
      name: "Linter Rule Memory",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),

    .target(
      name: "Linter Rule Testing",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),

    .target(
      name: "Linter Rule Idiom",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),

    .target(
      name: "Linter Rule Suppression",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),

    .target(
      name: "Linter Rule Package",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),

    .target(
      name: "Linter Rules",
      dependencies: [
        .product(name: "Linter", package: "swift-linter"),
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
      name: "Linter Rules Test Support",
      dependencies: [

        .product(name: "Linter Test Support", package: "swift-linter"),
        .product(name: "Byte", package: "swift-byte"),
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
        .product(name: "Linter", package: "swift-linter"),
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
