public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {
    public static let `blocking call in async` = Lint.Rule(
        id: "blocking call in async",
        default: .error,
        controls: [
            .init(
                id: "blocking call in async function",
                source: "func fetch() async -> Data { let d = pipe.fileHandleForReading.readDataToEndOfFile(); "
                    + "process.waitUntilExit(); return d }",
                path: "Sources/Concurrency Consumer/Fetch.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "blocking call in async pool closure",
                source: "func fetch() async throws -> Output { "
                    + "try await Kernel.Thread.Pool.shared.run { try Process.Spawn.run(configuration) } }",
                path: "Sources/Concurrency Consumer/Pooled.swift",
                expectation: .clean
            ),
            .init(
                id: "blocking call in async test",
                source: "func read() async throws { let d = try Data(contentsOf: url) }",
                path: "Tests/Concurrency Consumer Tests/Read Tests.swift",
                expectation: .clean
            ),
            .init(
                id: "blocking call in async synchronous function",
                source: "func fetch() -> Data { process.waitUntilExit(); return Data() }",
                path: "Sources/Concurrency Consumer/Synchronous.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !Lint.Scope.Target.isTest(source.path) else { return [] }
            let visitor = BlockingCallInAsyncVisitor(
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
internal let blockingCallInAsyncMessage: Swift::String =
    "[blocking call in async]: a call that blocks its thread runs in an async context. Under "
    + "NonisolatedNonsendingByDefault an async function runs on its caller's actor, so this blocks the main "
    + "actor when the caller is a view or a feature; under @concurrent it still holds a thread of the "
    + "cooperative pool. Fix: hand the blocking work to a thread made for it in a synchronous closure, "
    + "`try await Kernel.Thread.Pool.shared.run { ... }` (swift-threads), and run tools with "
    + "`Process.Spawn.run` (swift-process) inside it; or use the API's async form and await it."

internal final class BlockingCallInAsyncVisitor: SyntaxVisitor {
    static let members: Swift::Set<Swift::String> = [
        "waitUntilExit", "readDataToEndOfFile", "readToEnd", "readData",
    ]
    static let waitLabels: Swift::Set<Swift::String> = ["timeout", "wallTimeout"]
    static let functions: Swift::Set<Swift::String> = ["usleep", "sleep", "nanosleep"]
    static let contents: Swift::Set<Swift::String> = ["contentsOf", "contentsOfFile"]
    static let readers: Swift::Set<Swift::String> = ["Data", "String", "NSData", "NSString"]

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

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard blocks(node), !awaited(node), asynchronous(Syntax(node)) else { return .visitChildren }
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
                identifier: "blocking call in async",
                message: blockingCallInAsyncMessage
            )
        )
        return .visitChildren
    }

    private func blocks(_ call: FunctionCallExprSyntax) -> Swift::Bool {
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
            let name = member.declName.baseName.text
            let base = member.base?.trimmedDescription ?? ""
            if name == "sleep" { return base == "Thread" }
            if name == "run" { return base == "Process.Spawn" || base.hasSuffix("::Process.Spawn") }
            if name == "wait" { return waits(call, base: base) }
            return Self.members.contains(name)
        }
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            if Self.functions.contains(name) { return true }
            if Self.readers.contains(name), let label = call.arguments.first?.label?.text {
                return Self.contents.contains(label)
            }
        }
        return false
    }

    /// `semaphore.wait()` and `group.wait(timeout:)` block; `.wait(x)` and `Action.wait(id)` construct an enum case.
    private func waits(_ call: FunctionCallExprSyntax, base: Swift::String) -> Swift::Bool {
        guard let first = base.split(separator: ".").last?.first, !first.isUppercase else { return false }
        return call.arguments.allSatisfy { argument in
            argument.label.map { Self.waitLabels.contains($0.text) } ?? false
        }
    }

    private func awaited(_ call: FunctionCallExprSyntax) -> Swift::Bool {
        var current: Syntax? = call.parent
        while let parent = current {
            if parent.is(AwaitExprSyntax.self) { return true }
            if parent.is(TryExprSyntax.self) || parent.is(ExprListSyntax.self) || parent.is(SequenceExprSyntax.self) {
                current = parent.parent
                continue
            }
            return false
        }
        return false
    }

    private func asynchronous(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let parent = current {
            if let function = parent.as(FunctionDeclSyntax.self) {
                return function.signature.effectSpecifiers?.asyncSpecifier != nil
            }
            if let initializer = parent.as(InitializerDeclSyntax.self) {
                return initializer.signature.effectSpecifiers?.asyncSpecifier != nil
            }
            if let accessor = parent.as(AccessorDeclSyntax.self) {
                return accessor.effectSpecifiers?.asyncSpecifier != nil
            }
            if let closure = parent.as(ClosureExprSyntax.self) {
                return asynchronous(closure)
            }
            current = parent.parent
        }
        return false
    }

    private func asynchronous(_ closure: ClosureExprSyntax) -> Swift::Bool {
        if closure.signature?.effectSpecifiers?.asyncSpecifier != nil { return true }
        if task(closure) { return true }
        return AwaitFinder(closure).found
    }

    private func task(_ closure: ClosureExprSyntax) -> Swift::Bool {
        var current: Syntax? = closure.parent
        while let parent = current {
            if let call = parent.as(FunctionCallExprSyntax.self) {
                let called = call.calledExpression.trimmedDescription
                return called == "Task" || called == "Task.detached"
            }
            if parent.is(LabeledExprSyntax.self) || parent.is(LabeledExprListSyntax.self) {
                current = parent.parent
                continue
            }
            return false
        }
        return false
    }
}
