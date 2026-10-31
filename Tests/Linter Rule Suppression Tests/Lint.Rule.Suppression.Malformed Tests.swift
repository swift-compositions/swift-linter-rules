import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Suppression

@Suite
struct `malformed suppression directive Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `malformed suppression directive Tests` {
    static func findings(
        in source: String,
        file: String = "/Sources/X/File.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`malformed suppression directive`.observe(parsed, .warning).findings
    }
}

extension `malformed suppression directive Tests`.Unit {
    @Test
    func `block form without next or line is flagged`() {
        let source = """
            // swift-linter:disable unchecked call site
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `enable form is flagged (no enable directive exists)`() {
        let source = """
            // swift-linter:enable unchecked call site
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `empty rule id after next is flagged`() {
        let source = """
            // swift-linter:disable:next
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `whitespace-only rule id after next is flagged`() {

        let source =
            "// swift-linter:disable:next \nlet value = compute()"
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `wrong sub-token this is flagged (engine uses line)`() {
        let source = """
            // swift-linter:disable:this unchecked call site
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `missing space after slashes is flagged`() {
        let source = """
            //swift-linter:disable:next unchecked call site
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension `malformed suppression directive Tests`.`Edge Case` {
    @Test
    func `well-formed disable next is permitted`() {
        let source = """
            // swift-linter:disable:next unchecked call site
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `well-formed disable line trailing comment is permitted`() {
        let source = """
            let value = compute() // swift-linter:disable:line raw value access
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `swiftlint-prefixed directive is out of scope`() {
        let source = """
            // swiftlint:disable:next force_cast
            let value = compute() as! Int
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `swiftlint block form is out of scope`() {

        let source = """
            // swiftlint:disable no_foundation_import_warning typed_throws_required
            let value = compute()
            // swiftlint:enable no_foundation_import_warning typed_throws_required
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `prose mentioning the directive is not a directive`() {
        let source = """
            // see swift-linter:disable:next in the engine docs for the grammar
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `doc comment mention is not scanned`() {

        let source = """
            /// swift-linter:disable:next unchecked call site
            let value = compute()
            """
        let findings = `malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
