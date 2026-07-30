// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License 2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// Requires prose on every well-formed inline suppression directive.
/// Citation: `[LINT-SUPPRESS-002]`.
extension Lint.Rule {
  /// Requires prose on every well-formed inline suppression directive.
  public static let `suppression reason required` = Lint.Rule(
    id: "suppression reason required",
    default: .error,
    findings: { source, severity in
      suppressionReasonRequiredFindings(
        tree: source.tree,
        file: source.file,
        converter: source.converter,
        severity: severity
      )
    }
  )
}

@usableFromInline
internal let suppressionReasonRequiredMessage: Swift.String =
    "[suppression reason required] [LINT-SUPPRESS-002]: every "
    + "`swift-linter:disable:next` or `swift-linter:disable:line` directive "
    + "must have an immediately associated `// REASON:` continuation with "
    + "non-whitespace prose."

private let suppressionReasonRequiredPrefixes = [
    "// swift-linter:disable:next ",
    "// swift-linter:disable:line ",
]

private struct SuppressionReasonRequiredComment {
    let text: Swift.String
    let position: AbsolutePosition
    let line: Swift.Int
}

internal func suppressionReasonRequiredFindings(
    tree: SourceFileSyntax,
    file: Source.File,
    converter: SourceLocationConverter,
    severity: Diagnostic.Severity
) -> [Diagnostic.Record] {
    var comments: [SuppressionReasonRequiredComment] = []

    for token in tree.tokens(viewMode: .sourceAccurate) {
        suppressionReasonRequiredCollect(
            token.leadingTrivia,
            tokenStartPosition: token.position,
            converter: converter,
            into: &comments
        )
        suppressionReasonRequiredCollect(
            token.trailingTrivia,
            tokenStartPosition: token.endPositionBeforeTrailingTrivia,
            converter: converter,
            into: &comments
        )
    }

    var findings: [Diagnostic.Record] = []
    let lines = tree.description.split(separator: "\n", omittingEmptySubsequences: false)

  for comment in comments
    where suppressionReasonRequiredPrefixes.contains(where: comment.text.hasPrefix)
  {
    guard let prefix = suppressionReasonRequiredPrefixes.first(where: comment.text.hasPrefix),
      comment.text.dropFirst(prefix.count).contains(where: { !$0.isWhitespace })
    else { continue }

    // A continuation is immediately associated only when the physical
    // line directly below the directive is itself a REASON comment.
    // This excludes blank lines, intervening code (including code with a
    // trailing comment), and any later REASON that cannot repair an
    // empty immediate continuation.
    guard comment.line < lines.count else {
      findings.append(
        suppressionReasonRequiredFinding(
          for: comment, file: file, converter: converter, severity: severity))
      continue
    }

    let continuation = lines[comment.line].drop(while: { $0 == " " || $0 == "\t" })
    let reasonPrefix = "// REASON:"
    guard continuation.hasPrefix(reasonPrefix),
      continuation.dropFirst(reasonPrefix.count).contains(where: { !$0.isWhitespace })
    else {
      findings.append(
        suppressionReasonRequiredFinding(
          for: comment, file: file, converter: converter, severity: severity))
      continue
    }
  }
  return findings
}

private func suppressionReasonRequiredCollect(
    _ trivia: Trivia,
    tokenStartPosition: AbsolutePosition,
    converter: SourceLocationConverter,
    into comments: inout [SuppressionReasonRequiredComment]
) {
  var cursor = tokenStartPosition
  for piece in trivia {
    let position = cursor
    defer { cursor = cursor.advanced(by: piece.sourceLength.utf8Length) }
    guard case .lineComment(let text) = piece else { continue }
    comments.append(
      SuppressionReasonRequiredComment(
        text: text,
        position: position,
        line: converter.location(for: position).line
      )
    )
  }
}

private func suppressionReasonRequiredFinding(
    for comment: SuppressionReasonRequiredComment,
    file: Source.File,
    converter: SourceLocationConverter,
    severity: Diagnostic.Severity
) -> Diagnostic.Record {
  let location = converter.location(for: comment.position)
  return Diagnostic.Record(
    location: Source.Location(
      fileID: file.fileID,
      filePath: file.filePath,
      line: location.line,
      column: location.column
    ),
    severity: severity,
    identifier: "suppression reason required",
    message: suppressionReasonRequiredMessage
  )
}
