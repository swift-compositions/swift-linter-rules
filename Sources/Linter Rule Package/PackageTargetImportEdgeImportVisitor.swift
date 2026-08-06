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

/// Collects every imported module's leaf name (with the line of its
/// first sighting) from one target source file's parse.
package final class PackageTargetImportEdgeImportVisitor: SyntaxVisitor {
    /// module → line of first sighting in this file.
    package var imports: [Swift.String: Swift.Int] = [:]
    private let converter: SourceLocationConverter

    package init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override package func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let first = node.path.first else { return .skipChildren }
        let module = first.name.text
        if imports[module] == nil {
            imports[module] =
                converter.location(
                    for: node.positionAfterSkippingLeadingTrivia
                ).line
        }
        return .skipChildren
    }
}
