// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

/// Everything the target-import-edge rule needs from one manifest parse.
package struct PackageTargetImportEdgeManifest {
    package var targets: [PackageTargetImportEdgeTarget] = []
    /// `.library(name:targets:)` products — product name → member target names.
    package var products: [Swift.String: Swift.Set<Swift.String>] = [:]
    /// `.package(url: "...")` declarations.
    package var urlDependencies: [Swift.String] = []
    /// `.package(path: "...")` declarations.
    package var pathDependencies: [Swift.String] = []
}
