public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let comment = Lint.Rule(
        id: "comment",
        default: .warning,
        controls: [
            .init(
                id: "comment line",
                source: "// Implementation note\nstruct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment documentation",
                source: "/// A value.\n/** A block. */\nstruct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "comment block and trailing",
                source: "/* block */\nlet value = 1 // trailing",
                path: "Sources/Core/Value.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "comment marker",
                source: "// SAFETY: allocated once.\n// TRACKING: swift-institute/Issues#1\nstruct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "comment test",
                source: "// Test note\nstruct Value {}",
                path: "Tests/Core Tests/Value Tests.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment manifest",
                source: "// swift-tools-version: 6.4\n// The package.\nimport PackageDescription",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment directive",
                source: "// swift-linter:disable:next comment\nstruct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "comment directive reason",
                source: "func f() {\n    // swift-linter:disable:next do throws for typed catch\n    // REASON: Task.sleep throws untyped\n    try await Task.sleep(for: .seconds(1))\n}",
                path: "Sources/Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "comment reason without directive",
                source: "// REASON: no directive above\nstruct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment reason after a blank line",
                source: "// swift-linter:disable:next comment\n\n// REASON: detached\nstruct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment second reason line",
                source: "// swift-linter:disable:next comment\n// REASON: one\n// and more\nstruct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "comment string",
                source: "let text = \"// not a comment\"",
                path: "Sources/Core/Value.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            Lint.Rule.Comment.findings(
                in: source.tree,
                file: source.file,
                converter: source.converter,
                severity: severity
            )
        }
    )
}

extension Lint.Rule {

    public enum Comment {}
}

extension Lint.Rule.Comment {

    @usableFromInline
    internal static let message: Swift::String =
        "[comment] Research/no-source-comments.md: Swift carries no comments, `///` and `/* */` included; a name says what, a type or a test "
        + "whose name states it says why, an issue link in a name records a workaround, and history is dropped. "
        + "Admitted: `// swift-linter:` directives and the one `// REASON:` line directly under one."

    internal static let tools: Swift::String = "// swift-tools-version:"

    internal static func findings(
        in tree: SourceFileSyntax,
        file: Source.File,
        converter: SourceLocationConverter,
        severity: Diagnostic.Severity
    ) -> [Diagnostic.Record] {
        tree.tokens(viewMode: .sourceAccurate).flatMap { token in
            Self.offsets(in: token.leadingTrivia, from: token.position)
                + Self.offsets(in: token.trailingTrivia, from: token.endPositionBeforeTrailingTrivia)
        }
        .map { position in
            let location = converter.location(for: position)
            return Diagnostic.Record(
                location: Source.Location(
                    fileID: file.fileID,
                    filePath: file.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "comment",
                message: Self.message
            )
        }
    }

    internal static func offsets(in trivia: Trivia, from start: AbsolutePosition) -> [AbsolutePosition] {
        let pieces = Swift::Array(trivia)
        let admitted = Self.admitted(pieces)
        var position = start
        var offsets: [AbsolutePosition] = []
        for (index, piece) in pieces.enumerated() {
            defer { position = position.advanced(by: piece.sourceLength.utf8Length) }
            guard Self.isComment(piece), !admitted.contains(index) else { continue }
            offsets.append(position)
        }
        return offsets
    }

    internal static func isComment(_ piece: TriviaPiece) -> Swift::Bool {
        switch piece {
        case .lineComment, .docLineComment, .blockComment, .docBlockComment: true
        default: false
        }
    }

    internal static func admitted(_ pieces: [TriviaPiece]) -> Swift::Set<Swift::Int> {
        var admitted: Swift::Set<Swift::Int> = []
        for (index, piece) in pieces.enumerated() {
            guard case .lineComment(let text) = piece else { continue }
            if text.hasPrefix("// swift-linter:") || text.hasPrefix(Self.tools) {
                admitted.insert(index)
                continue
            }
            guard text.hasPrefix("// REASON:"),
                let previous = Self.previousLine(pieces, before: index),
                case .lineComment(let prior) = pieces[previous],
                prior.hasPrefix("// swift-linter:disable:")
            else { continue }
            admitted.insert(index)
        }
        return admitted
    }

    internal static func previousLine(_ pieces: [TriviaPiece], before index: Swift::Int) -> Swift::Int? {
        var cursor = index - 1
        while cursor >= 0, Self.isSpaceOrTab(pieces[cursor]) { cursor -= 1 }
        guard cursor >= 0 else { return nil }
        switch pieces[cursor] {
        case .newlines(1), .carriageReturnLineFeeds(1): cursor -= 1
        default: return nil
        }
        while cursor >= 0, Self.isSpaceOrTab(pieces[cursor]) { cursor -= 1 }
        return cursor >= 0 ? cursor : nil
    }

    internal static func isSpaceOrTab(_ piece: TriviaPiece) -> Swift::Bool {
        switch piece {
        case .spaces, .tabs: true
        default: false
        }
    }
}
