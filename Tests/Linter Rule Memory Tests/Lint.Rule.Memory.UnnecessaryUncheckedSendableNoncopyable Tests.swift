import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Memory

@Suite
struct `unchecked sendable noncopyable Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `unchecked sendable noncopyable Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unchecked sendable noncopyable`.observe(parsed, .warning).findings
    }
}

extension `unchecked sendable noncopyable Tests`.Unit {
    @Test
    func `noncopyable struct with unchecked Sendable is flagged`() {
        let source = """
            struct Reader: ~Copyable, @unchecked Sendable {}
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct with plain Sendable is permitted`() {
        let source = """
            struct Reader: ~Copyable, Sendable {}
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `copyable struct with unchecked Sendable is not flagged here`() {

        let source = """
            final class Foo: @unchecked Sendable {}
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct without Sendable is not flagged`() {
        let source = """
            struct Reader: ~Copyable {}
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct with unsafe unchecked Sendable is still flagged (drop unchecked)`() {

        let source = """
            struct Arena: ~Copyable, @unsafe @unchecked Sendable {}
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `regular copyable struct with Sendable is not flagged`() {
        let source = """
            struct Foo: Sendable {}
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension `unchecked sendable noncopyable Tests`.`Edge Case` {
    @Test
    func `noncopyable struct storing only Sendable values is flagged`() {
        let source = """
            struct Reader: ~Copyable, @unchecked Sendable {
                let count: Int
                var name: String
                var handler: @Sendable () -> Void
            }
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct storing an unsafe pointer is not flagged`() {
        let source = """
            struct Arena: ~Copyable, @unchecked Sendable {
                let base: UnsafeMutableRawPointer
                let count: Int
            }
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct storing a non-Sendable closure is not flagged`() {
        let source = """
            struct Callback: ~Copyable, @unchecked Sendable {
                let body: (() -> Void)?
            }
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `static and computed pointer properties do not exempt the struct`() {
        let source = """
            struct Reader: ~Copyable, @unchecked Sendable {
                static let shared: OpaquePointer? = nil
                var address: UnsafeRawPointer? { nil }
                let count: Int
            }
            """
        let findings = `unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
