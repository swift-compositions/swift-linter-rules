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

package import SwiftSyntax

/// One target declaration read from a manifest parse.
package struct PackageTargetImportEdgeTarget {
    package var name: Swift.String = ""
    package var kind: Kind = .target
    package var explicitPath: Swift.String?
    package var dependencies: [Dependency] = []
    package var namePosition: AbsolutePosition = AbsolutePosition(utf8Offset: 0)
}
