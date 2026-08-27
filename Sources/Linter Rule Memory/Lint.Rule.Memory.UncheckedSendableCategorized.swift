public import Linter
internal import SwiftSyntax

extension Lint.Rule {

  public static let `unchecked sendable categorization` = Lint.Rule(
    id: "unchecked sendable categorization",
    default: .warning,
    controls: [
      .init(
        id: "unchecked sendable categorization unsafe conformance",
        source: "final class Fixture: @unsafe @unchecked Sendable {}",
        path: "Controls/UncheckedSendableCategorization.swift",
        expectation: .findings(1)
      )
    ],
    observe: Lint.Rule.measured { source, severity in
      let visitor = MemoryUncheckedSendableCategorizedVisitor(
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
internal let `unchecked sendable categorization message`: Swift.String =
  "[unchecked sendable categorization] [MEM-SAFE-024]: `@unchecked Sendable` "
  + "MUST NOT be paired with `@unsafe` on the same conformance clause. Per "
  + "SE-0458, `@unsafe` is scoped to the four memory-safety dimensions "
  + "(lifetime/bounds/type/initialization); thread safety is the separate "
  + "fifth dimension carried by `@unchecked Sendable` alone. Drop the "
  + "`@unsafe` from the conformance clause. If memory-safety unsafety is "
  + "fundamental to the type, apply `@unsafe` on the type or extension "
  + "declaration (a different syntactic position) instead. The Category "
  + "(A/B/C/D) is documentation discipline carried in a `## Safety Invariant` "
  + "doc-comment or adjacent `// SAFETY:` / `// WHY:` block, NOT a trigger "
  + "for `@unsafe`."

internal final class MemoryUncheckedSendableCategorizedVisitor: SyntaxVisitor {
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

  private func hasUnsafeAttributeOnInherited(_ inherited: InheritedTypeSyntax) -> Bool {

    if let attributed = inherited.type.as(AttributedTypeSyntax.self) {
      for attribute in attributed.attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "unsafe" {
          return true
        }
      }
    }
    return false
  }

  private func hasUncheckedAttribute(_ inherited: InheritedTypeSyntax) -> Bool {
    if let attributed = inherited.type.as(AttributedTypeSyntax.self) {
      for attribute in attributed.attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "unchecked" {
          return true
        }
      }
    }
    return false
  }

  private func isSendableInherited(_ inherited: InheritedTypeSyntax) -> Bool {
    var current = inherited.type
    while let attributed = current.as(AttributedTypeSyntax.self) {
      current = attributed.baseType
    }
    if let identifier = current.as(IdentifierTypeSyntax.self) {
      return identifier.name.text == "Sendable"
    }
    if let member = current.as(MemberTypeSyntax.self) {
      return member.name.text == "Sendable"
    }
    return false
  }

  private func check(_ inheritanceClause: InheritanceClauseSyntax?) {
    guard let inheritanceClause else { return }
    for inherited in inheritanceClause.inheritedTypes {
      guard isSendableInherited(inherited) else { continue }
      guard hasUncheckedAttribute(inherited) else { continue }

      guard hasUnsafeAttributeOnInherited(inherited) else { continue }
      let location = converter.location(for: inherited.positionAfterSkippingLeadingTrivia)
      matches.append(
        Diagnostic.Record(
          location: Source.Location(
            fileID: source.fileID,
            filePath: source.filePath,
            line: location.line,
            column: location.column
          ),
          severity: severity,
          identifier: "unchecked sendable categorization",
          message: `unchecked sendable categorization message`
        )
      )
    }
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    check(node.inheritanceClause)
    return .visitChildren
  }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    check(node.inheritanceClause)
    return .visitChildren
  }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    check(node.inheritanceClause)
    return .visitChildren
  }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
    check(node.inheritanceClause)
    return .visitChildren
  }
  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    check(node.inheritanceClause)
    return .visitChildren
  }
}
