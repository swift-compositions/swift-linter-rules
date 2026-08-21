public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {

    public static let `redundant refinement` = Lint.Rule(
        id: "redundant refinement",
        default: .warning,
        findings: { source, severity in
            let visitor = IdiomRedundantRefinementVisitor(
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
internal func idiomRedundantRefinementMessage(
    refining: Swift.String,
    refined: Swift.String
) -> Swift.String {
    "[redundant refinement] [API-IMPL-024]: "
        + "`\(refining) & \(refined)` — `\(refining)` already refines `\(refined)` "
        + "in the standard library. The `& \(refined)` half is redundant; "
        + "the compiler enforces `\(refined)` through `\(refining)`. Drop "
        + "the redundant member."
}

internal final class IdiomRedundantRefinementVisitor: SyntaxVisitor {
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

    override func visit(_ node: CompositionTypeSyntax) -> SyntaxVisitorContinueKind {

        var leaves: [(name: Swift.String, position: AbsolutePosition)] = []
        for element in node.elements {
            if let name = leafName(of: element.type) {
                leaves.append((name, element.type.positionAfterSkippingLeadingTrivia))
            }
        }

        var reportedPositions: Swift.Set<AbsolutePosition> = []
        leaves.indices.forEach { i in
            leaves.indices.forEach { j in
                guard i != j else { return }
                let refining = leaves[i].name
                let refined = leaves[j].name
                let isRedundant = idiomKnownStdlibRefinements.contains { pair in
                    pair.refining == refining && pair.refined == refined
                }
                guard isRedundant else { return }
                let position = leaves[j].position
                guard !reportedPositions.contains(position) else { return }
                reportedPositions.insert(position)
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
                        identifier: "redundant refinement",
                        message: idiomRedundantRefinementMessage(
                            refining: refining,
                            refined: refined
                        )
                    )
                )
            }
        }
        return .visitChildren
    }

    private func leafName(of type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        if let some = type.as(SomeOrAnyTypeSyntax.self) {
            return leafName(of: some.constraint)
        }
        return nil
    }
}
