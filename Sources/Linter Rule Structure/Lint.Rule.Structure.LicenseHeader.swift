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

public import Linter_Primitives
internal import SwiftSyntax

/// F9 predicate parity (2026-08-06) — Apache-2.0 license header on every
/// `Sources/**/*.swift` file.
///
/// Mirrors the incumbent Python surface
/// `swift-institute/.github/.github/scripts/audit-license-header.py`
/// (γ-1b Stage 1) exactly:
///
/// - Scope: only files whose run-root-relative path starts with a
///   `Sources` component. `Tests/**`, `Package.swift`, and
///   `Package@*.swift` never fire. The Python anchors `parts[0] ==
///   "Sources"` at the package root; this rule anchors the same
///   predicate at the lint run root. When a run root sits above the
///   package root the rule stays silent for that file (fail-closed:
///   out-of-anchor files are out of scope, never false-fired).
/// - Detection: case-insensitive substring `apache` AND `2.0` anywhere
///   in the first 30 lines — forgiving the same variations the Python
///   forgives ("Apache License, Version 2.0", "Apache License v2.0",
///   "Apache-2.0", ...).
///
/// Citation: swift-institute/.github#358 transaction F9.
extension Lint.Rule {
    /// Flags a `Sources/**/*.swift` file whose first 30 lines carry no Apache-2.0 license header (mirror of audit-license-header.py).
    public static let `license header` = Lint.Rule(
        id: "license header",
        // ADVISORY at introduction per the standing graduation
        // discipline — promote to `.error` only after fleet validation.
        default: .warning,
        findings: { source, severity in
            guard structureLicenseHeaderApplies(toPath: Swift.String(describing: source.path)) else {
                return []
            }
            guard !structureLicenseHeaderIsPresent(in: source.tree.description) else {
                return []
            }
            return [
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: 1,
                        column: 1
                    ),
                    severity: severity,
                    identifier: "license header",
                    message: structureLicenseHeaderMessage
                )
            ]
        }
    )
}

/// The line window the header must appear in — identical to the
/// Python's `HEADER_LINE_LIMIT`.
@usableFromInline
internal let structureLicenseHeaderLineLimit: Swift.Int = 30

@usableFromInline
internal let structureLicenseHeaderMessage: Swift.String =
    "[license header]: every `Sources/**/*.swift` file must carry the "
    + "Apache-2.0 license header within its first 30 lines. Add the "
    + "project's standard header block (any spelling containing "
    + "`Apache` and `2.0` is accepted — e.g. `Licensed under Apache "
    + "License v2.0`)."

/// Mirror of the Python `is_excluded` (inverted): the rule applies only
/// to `Sources/**/*.swift`, excluding `Tests/**`, `Package.swift`, and
/// `Package@*.swift`.
@usableFromInline
internal func structureLicenseHeaderApplies(toPath path: Swift.String) -> Swift.Bool {
    let parts = path.split(separator: "/").map(Swift.String.init)
    guard let name = parts.last else { return false }
    guard name.hasSuffix(".swift") else { return false }
    if name == "Package.swift" { return false }
    if name.hasPrefix("Package@") { return false }
    guard let first = parts.first else { return false }
    if first == "Tests" { return false }
    return first == "Sources"
}

/// Mirror of the Python `has_apache_header`: case-insensitive substring
/// `apache` AND `2.0` anywhere in the first 30 lines.
@usableFromInline
internal func structureLicenseHeaderIsPresent(in source: Swift.String) -> Swift.Bool {
    let head = source
        .split(separator: "\n", omittingEmptySubsequences: false)
        .prefix(structureLicenseHeaderLineLimit)
        .joined(separator: "\n")
        .lowercased()
    return head.contains("apache") && head.contains("2.0")
}
