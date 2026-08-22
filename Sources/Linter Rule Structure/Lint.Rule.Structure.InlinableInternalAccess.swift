public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {

  public static let `inlinable internal access` = Lint.Rule(
    id: "inlinable internal access",

    default: .error,
    controls: [
      .init(
        id: "inlinable internal access internal function",
        source: """
          @inlinable
          func helper() {}
          """,
        path: "Controls/InlinableInternalAccess.swift",
        expectation: .findings(1)
      )
    ],
    observe: Lint.Rule.measured { source, severity in
      let visitor = StructureInlinableInternalAccessVisitor(
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
internal let `inlinable internal access exemption suffix`: Swift.String =
  " (The rule does not fire when the enclosing type is itself below "
  + "`package` access, since there the `package` upgrade is "
  + "compiler-illegal.) For a legitimate remaining site, suppress with "
  + "`// swift-linter:disable:next inlinable internal access` plus a "
  + "`// REASON:` continuation."

@usableFromInline
internal let `inlinable internal access message`: Swift.String =
  "[inlinable internal access] [PATTERN-052]: `@inlinable` cross-module access "
  + "requires non-`internal` visibility. Upgrade to `package` (preferred for "
  + "impl-only surface) or `public` — do NOT add `@usableFromInline`, which "
  + "Swift rejects on an `@inlinable` decl as `has no effect`."
  + `inlinable internal access exemption suffix`

@usableFromInline
internal let `inlinable internal access initializer message`: Swift.String =
  "[inlinable internal access] [PATTERN-052]: `@inlinable` cross-module access "
  + "requires non-`internal` visibility. For initializers, prefer `package init` "
  + "— Swift rejects `@usableFromInline` on `@inlinable init` as `has no "
  + "effect` (the func/var pairing does not apply here). Use `package init` "
  + "for impl-only surface, or upgrade to `public init`."
  + `inlinable internal access exemption suffix`

private func structureTypeIsPackageUpgradable(_ modifiers: DeclModifierListSyntax) -> Bool {
  for modifier in modifiers {
    switch modifier.name.tokenKind {
    case .keyword(.public), .keyword(.package), .keyword(.open):
      return true

    default:
      continue
    }
  }
  return false
}

private func structureSimpleTypeName(_ type: TypeSyntax) -> Swift.String? {
  if let optional = type.as(OptionalTypeSyntax.self) {
    return structureSimpleTypeName(optional.wrappedType)
  }
  if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return structureSimpleTypeName(iuo.wrappedType)
  }
  if let identifier = type.as(IdentifierTypeSyntax.self) {
    return identifier.name.text
  }
  if let member = type.as(MemberTypeSyntax.self) {
    return member.name.text
  }
  return nil
}

private func structureCollectNonUpgradableTypeNames(
  _ node: Syntax,
  into names: inout Swift.Set<Swift.String>
) {
  func record(_ identifier: TokenSyntax, _ modifiers: DeclModifierListSyntax) {
    if !structureTypeIsPackageUpgradable(modifiers) {
      names.insert(identifier.text)
    }
  }
  if let decl = node.as(StructDeclSyntax.self) {
    record(decl.name, decl.modifiers)
  } else if let decl = node.as(ClassDeclSyntax.self) {
    record(decl.name, decl.modifiers)
  } else if let decl = node.as(EnumDeclSyntax.self) {
    record(decl.name, decl.modifiers)
  } else if let decl = node.as(ActorDeclSyntax.self) {
    record(decl.name, decl.modifiers)
  } else if let decl = node.as(ProtocolDeclSyntax.self) {
    record(decl.name, decl.modifiers)
  } else if let decl = node.as(TypeAliasDeclSyntax.self) {
    record(decl.name, decl.modifiers)
  }
  for child in node.children(viewMode: .sourceAccurate) {
    structureCollectNonUpgradableTypeNames(child, into: &names)
  }
}

internal final class StructureInlinableInternalAccessVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []

  private var nonUpgradableTypeNames: Swift.Set<Swift.String>?

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  private func nonUpgradableNames(from node: some SyntaxProtocol) -> Swift.Set<Swift.String> {
    if let cached = nonUpgradableTypeNames { return cached }
    var names: Swift.Set<Swift.String> = []
    structureCollectNonUpgradableTypeNames(node.root, into: &names)
    nonUpgradableTypeNames = names
    return names
  }

  private func enclosingChainForbidsPackageUpgrade(_ node: some SyntaxProtocol) -> Bool {
    var current = node.parent
    while let ancestor = current {
      if let decl = ancestor.as(StructDeclSyntax.self) {
        if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
      } else if let decl = ancestor.as(ClassDeclSyntax.self) {
        if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
      } else if let decl = ancestor.as(EnumDeclSyntax.self) {
        if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
      } else if let decl = ancestor.as(ActorDeclSyntax.self) {
        if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
      } else if let decl = ancestor.as(ExtensionDeclSyntax.self) {
        if let name = structureSimpleTypeName(decl.extendedType),
          nonUpgradableNames(from: node).contains(name)
        {
          return true
        }
      }
      current = ancestor.parent
    }
    return false
  }

  private func initializerParameterForbidsPackageUpgrade(_ node: InitializerDeclSyntax) -> Bool {
    let names = nonUpgradableNames(from: node)
    for parameter in node.signature.parameterClause.parameters {
      if let name = structureSimpleTypeName(parameter.type), names.contains(name) {
        return true
      }
    }
    return false
  }

  private func hasInlinableAttribute(_ attributes: AttributeListSyntax) -> Bool {
    for attribute in attributes {
      guard let attr = attribute.as(AttributeSyntax.self) else { continue }
      if attr.attributeName.trimmedDescription == "inlinable" {
        return true
      }
    }
    return false
  }

  private func hasNonInternalAccess(_ modifiers: DeclModifierListSyntax) -> Bool {
    for modifier in modifiers {
      switch modifier.name.tokenKind {
      case .keyword(.public), .keyword(.package), .keyword(.open):
        return true

      default:
        continue
      }
    }
    return false
  }

  private func hasUsableFromInline(_ attributes: AttributeListSyntax) -> Bool {
    for attribute in attributes {
      guard let attr = attribute.as(AttributeSyntax.self) else { continue }
      if attr.attributeName.trimmedDescription == "usableFromInline" {
        return true
      }
    }
    return false
  }

  private func emit(at position: AbsolutePosition, message: Swift.String) {
    let location = converter.location(for: position)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "inlinable internal access",
        message: message
      )
    )
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    if hasInlinableAttribute(node.attributes),
      !hasNonInternalAccess(node.modifiers),
      !hasUsableFromInline(node.attributes),
      !enclosingChainForbidsPackageUpgrade(node)
    {
      emit(
        at: node.name.positionAfterSkippingLeadingTrivia,
        message: `inlinable internal access message`
      )
    }
    return .visitChildren
  }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    if hasInlinableAttribute(node.attributes),
      !hasNonInternalAccess(node.modifiers),
      !hasUsableFromInline(node.attributes),
      !enclosingChainForbidsPackageUpgrade(node)
    {
      emit(
        at: node.bindingSpecifier.positionAfterSkippingLeadingTrivia,
        message: `inlinable internal access message`
      )
    }
    return .visitChildren
  }

  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    if hasInlinableAttribute(node.attributes),
      !hasNonInternalAccess(node.modifiers),
      !hasUsableFromInline(node.attributes),
      !enclosingChainForbidsPackageUpgrade(node),
      !initializerParameterForbidsPackageUpgrade(node)
    {
      emit(
        at: node.initKeyword.positionAfterSkippingLeadingTrivia,
        message: `inlinable internal access initializer message`
      )
    }
    return .visitChildren
  }
}
