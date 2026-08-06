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
    /// The manifest factory the target was declared with.
    package enum Kind {
        case target
        case executableTarget
        case testTarget
        case macro
    }
}
