public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {

  public static let `malformed suppression directive` = Lint.Rule(
    id: "malformed suppression directive",
    default: .warning,
    controls: [
      .init(
        id: "malformed suppression directive block form",
        source: """
          // swift-linter:disable unchecked call site
          let value = compute()
          """,
        path: "Controls/MalformedSuppressionDirective.swift",
        expectation: .findings(1)
      )
    ],
    observe: Lint.Rule.measured { source, severity in
      malformed(
        tree: source.tree,
        file: source.file,
        converter: source.converter,
        severity: severity
      )
    }
  )
}

@usableFromInline
internal let `malformed suppression directive message`: Swift.String =
  "[malformed suppression directive] [LINT-SUPPRESS-001]: this `swift-linter:` "
  + "suppression directive does not match the engine grammar and is silently "
  + "ignored — the finding it targets is NOT suppressed. Use "
  + "`// swift-linter:disable:next <rule-id>` or "
  + "`// swift-linter:disable:line <rule-id>` (no block form and no `enable` "
  + "form exist)."

private let malformedSuppressionDisableNextPrefix = "// swift-linter:disable:next "
private let malformedSuppressionDisableLinePrefix = "// swift-linter:disable:line "

internal func malformed(
  tree: SourceFileSyntax,
  file: Source.File,
  converter: SourceLocationConverter,
  severity: Diagnostic.Severity
) -> [Diagnostic.Record] {
  var matches: [Diagnostic.Record] = []
  for token in tree.tokens(viewMode: .sourceAccurate) {
    scanTriviaForMalformedDirectives(
      token.leadingTrivia,
      tokenStartPosition: token.position,
      converter: converter,
      file: file,
      severity: severity,
      into: &matches
    )
    scanTriviaForMalformedDirectives(
      token.trailingTrivia,
      tokenStartPosition: token.endPositionBeforeTrailingTrivia,
      converter: converter,
      file: file,
      severity: severity,
      into: &matches
    )
  }
  return matches
}

private func scanTriviaForMalformedDirectives(
  _ trivia: Trivia,
  tokenStartPosition: AbsolutePosition,
  converter: SourceLocationConverter,
  file: Source.File,
  severity: Diagnostic.Severity,
  into matches: inout [Diagnostic.Record]
) {
  var cursor = tokenStartPosition
  for piece in trivia {
    let pieceStart = cursor
    let pieceLength = piece.sourceLength
    defer { cursor = cursor.advanced(by: pieceLength.utf8Length) }

    guard case .lineComment(let text) = piece else { continue }
    guard isMalformedDirective(text) else { continue }

    let location = converter.location(for: pieceStart)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: file.fileID,
          filePath: file.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "malformed suppression directive",
        message: `malformed suppression directive message`
      )
    )
  }
}

internal func isMalformedDirective(_ text: Swift.String) -> Swift.Bool {
  guard text.hasPrefix("//") else { return false }
  var rest = text.dropFirst(2)
  while let first = rest.first, first == " " { rest = rest.dropFirst() }
  guard rest.hasPrefix("swift-linter:") else { return false }

  for prefix in [malformedSuppressionDisableNextPrefix, malformedSuppressionDisableLinePrefix]
  where text.hasPrefix(prefix) {
    let suffix = text.dropFirst(prefix.count)

    if suffix.contains(where: { !$0.isWhitespace }) { return false }
  }
  return true
}
