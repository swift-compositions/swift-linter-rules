import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_Structure

@Suite
struct `comment Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

extension `comment Tests` {
    static func lines(in source: String, file: String = "/Sources/X/File.swift") -> [String] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.comment.observe(parsed, .warning).findings.map { "\($0.location.line)" }
    }
}

extension `comment Tests`.Unit {
    @Test
    func `controls hold`() {
        for outcome in Lint.Rule.comment.outcomes() {
            #expect(outcome.holds, "\(outcome)")
        }
    }

    @Test
    func `every comment kind is found on its own line`() {
        let source = """
            /// Documentation.
            struct Value {
                // Line.
                /* Block. */
                let value = 1 // Trailing.
            }
            """
        #expect(`comment Tests`.lines(in: source) == ["1", "3", "4", "5"])
    }
}

extension `comment Tests`.`Edge Case` {
    @Test
    func `a directive and its reason are admitted inside a body`() {
        let source = """
            func f() {
                // swift-linter:disable:next comment
                // REASON: the reason.
                let value = 1
            }
            """
        #expect(`comment Tests`.lines(in: source).isEmpty)
    }

    @Test
    func `the tools version line is admitted only as written by SwiftPM`() {
        #expect(`comment Tests`.lines(in: "// swift-tools-version: 6.4\nlet x = 1").isEmpty)
        #expect(`comment Tests`.lines(in: "// tools version 6.4\nlet x = 1") == ["1"])
    }
}
