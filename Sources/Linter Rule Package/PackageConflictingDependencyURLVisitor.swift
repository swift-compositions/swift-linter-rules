package import SwiftSyntax

package final class PackageConflictingDependencyURLVisitor: SyntaxVisitor {
    package var urls: [(url: Swift::String, position: AbsolutePosition)] = []

    package init() {
        super.init(viewMode: .sourceAccurate)
    }

    override package func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "package",
            let argument = node.arguments.first(where: { $0.label?.text == "url" }),
            let literal = argument.expression.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            let segment = literal.segments.first?.as(StringSegmentSyntax.self)
        else { return .visitChildren }
        urls.append((segment.content.text, literal.positionAfterSkippingLeadingTrivia))
        return .visitChildren
    }
}
