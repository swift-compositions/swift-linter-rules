public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {

    public static let `usable from inline internal import` = Lint.Rule(
        id: "usable from inline internal import",
        default: .warning,
        findings: { source, severity in
            let visitor = StructureUsableFromInlineInternalImportVisitor(
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
internal let structureUsableFromInlineInternalImportMessage: Swift.String =
    "[usable from inline internal import] [PATTERN-055]: file pairs "
    + "`@usableFromInline` with `internal import` of a referenced module. "
    + "Swift rejects `@usableFromInline` bodies that reach identifiers in "
    + "internally-imported modules at compile time. Either downgrade the "
    + "decl's visibility or upgrade the import to `public` / `package`."

internal final class StructureUsableFromInlineInternalImportVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    var usableFromInlineReferencedNames: Swift.Set<Swift.String> = []
    var internalImportModules: [StructureUsableFromInlineInternalImportModule] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func hasUsableFromInlineAttribute(_ attributes: AttributeListSyntax) -> Swift.Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                identifier.name.text == "usableFromInline"
            {
                return true
            }
            if attr.attributeName.trimmedDescription == "usableFromInline" {
                return true
            }
        }
        return false
    }

    private func collectIdentifierTexts(in node: some SyntaxProtocol) {
        for token in node.tokens(viewMode: .sourceAccurate) {
            if case .identifier(let text) = token.tokenKind {
                usableFromInlineReferencedNames.insert(text)
            }
        }
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        var isInternal: Swift.Bool = false
        for modifier in node.modifiers {
            if case .keyword(.internal) = modifier.name.tokenKind {
                isInternal = true
                break
            }
        }
        guard isInternal else { return .visitChildren }
        let leafName = importDeclLeafModuleName(node)
        internalImportModules.append(
            .init(
                position: node.importKeyword.positionAfterSkippingLeadingTrivia,
                leafName: leafName
            )
        )
        return .visitChildren
    }

    private func importDeclLeafModuleName(_ node: ImportDeclSyntax) -> Swift.String {
        let path = node.path
        guard let last = path.last else { return "" }
        return last.name.text
    }

    func finalize() {
        for module in internalImportModules {
            guard usableFromInlineReferencedNames.contains(module.leafName) else {
                continue
            }
            let location = converter.location(for: module.position)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "usable from inline internal import",
                    message: structureUsableFromInlineInternalImportMessage
                )
            )
        }
    }

    override func visitPost(_: SourceFileSyntax) {
        finalize()
    }
}
