public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {

  public static let `mock factory zero collision` = Lint.Rule(
    id: "mock factory zero collision",
    default: .warning,
    controls: [
      .init(
        id: "mock factory zero collision bare tag",
        source: "let value = unsafeBitCast(tag, to: UnownedJob.self)",
        path: "/Controls/Tests/MockFactoryZeroCollision.swift",
        expectation: .findings(1)
      )
    ],
    observe: Lint.Rule.measured { source, severity in
      let visitor = TestingMockFactoryZeroCollisionVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

@usableFromInline
internal let `mock factory zero collision message`: Swift.String =
  "[mock factory zero collision] [TEST-028]: `unsafeBitCast(tag, to: T.self)` "
  + "for pointer-wrapping `BitwiseCopyable` `T` collides with `Optional<T>.none` "
  + "when `tag == 0`. Offset: `unsafeBitCast(tag &+ 1, to: T.self)`."

internal final class TestingMockFactoryZeroCollisionVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  private func isUnsafeBitCast(_ expr: ExprSyntax) -> Swift.Bool {
    if let identifier = expr.as(DeclReferenceExprSyntax.self) {
      return identifier.baseName.text == "unsafeBitCast"
    }
    return false
  }

  private func firstArgumentLooksRaw(_ argument: LabeledExprSyntax) -> Swift.Bool {
    let text = argument.expression.trimmedDescription
    if text.contains("&+") || text.contains("+ 1") || text.contains(" + ") {
      return false
    }
    return true
  }

  private func firstArgumentLooksLikeIntegerTag(_ argument: LabeledExprSyntax) -> Swift.Bool {

    if argument.expression.is(AsExprSyntax.self) {
      return false
    }

    if argument.expression.is(MemberAccessExprSyntax.self) {
      return false
    }
    return true
  }

  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {

    if !source.filePath.contains("/Tests/") {
      return .visitChildren
    }
    guard isUnsafeBitCast(node.calledExpression) else { return .visitChildren }
    guard let firstArgument = node.arguments.first else { return .visitChildren }
    guard firstArgumentLooksRaw(firstArgument) else { return .visitChildren }
    guard firstArgumentLooksLikeIntegerTag(firstArgument) else { return .visitChildren }
    let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "mock factory zero collision",
        message: `mock factory zero collision message`
      )
    )
    return .visitChildren
  }
}
