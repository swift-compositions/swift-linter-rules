internal import SwiftSyntax

internal final class AwaitFinder: SyntaxVisitor {
    var found = false

    init(_ closure: ClosureExprSyntax) {
        super.init(viewMode: .sourceAccurate)
        walk(closure.statements)
    }

    override func visit(_ node: AwaitExprSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }
}
