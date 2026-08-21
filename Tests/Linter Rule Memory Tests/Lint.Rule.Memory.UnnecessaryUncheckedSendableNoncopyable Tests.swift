import Linter_Primitives
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `unchecked sendable noncopyable Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`unchecked sendable noncopyable Tests` {
    static func findings(
        in source: Swift.String,
        file: Swift.String = "Sources/X/Test.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unchecked sendable noncopyable`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`unchecked sendable noncopyable Tests`.Unit {
    @Test
    func `noncopyable struct with unchecked Sendable is flagged`() {
        let source = """
            struct Reader: ~Copyable, @unchecked Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct with plain Sendable is permitted`() {
        let source = """
            struct Reader: ~Copyable, Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `copyable struct with unchecked Sendable is not flagged here`() {

        let source = """
            final class Foo: @unchecked Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct without Sendable is not flagged`() {
        let source = """
            struct Reader: ~Copyable {}
            """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct with unsafe unchecked Sendable is still flagged (drop unchecked)`() {

        let source = """
            struct Arena: ~Copyable, @unsafe @unchecked Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `regular copyable struct with Sendable is not flagged`() {
        let source = """
            struct Foo: Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
