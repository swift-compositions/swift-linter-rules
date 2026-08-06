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

extension PackageTargetImportEdgeTarget {
    /// One entry of a target's `dependencies:` array.
    package enum Dependency {
        /// `.target(name: "X")`
        case target(Swift.String)
        /// `.product(name: "X", package: ...)`
        case product(Swift.String)
        /// `"X"` or `.byName(name: "X")`
        case byName(Swift.String)
    }
}
