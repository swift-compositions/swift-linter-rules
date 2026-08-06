// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Linter_Primitives
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `license header Tests` {
        @Suite struct Unit {}
        @Suite struct Exemption {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`license header Tests` {
    static func findings(
        in source: String,
        path: String = "Sources/Example/Example.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(
            from: source,
            file: path,
            path: Lint.Source.Path(path)
        )
        return Lint.Rule.`license header`.findings(parsed, .warning)
    }

    static let header = """
        // ===------------------------------------------------------===//
        //
        // This source file is part of the example open source project
        //
        // Licensed under Apache License v2.0
        //
        // ===------------------------------------------------------===//

        """
}

extension Lint.Rule.`license header Tests`.Unit {
    @Test
    func `missing header in Sources file is flagged`() {
        let findings = Lint.Rule.`license header Tests`.findings(
            in: "func helper() -> Int { 0 }"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "license header")
            #expect(findings[0].severity == .warning)
            #expect(findings[0].location.line == 1)
        }
    }

    @Test
    func `standard header block is accepted`() {
        let source = Lint.Rule.`license header Tests`.header + "\nfunc helper() -> Int { 0 }"
        #expect(Lint.Rule.`license header Tests`.findings(in: source).isEmpty)
    }

    @Test
    func `spelling variants are accepted`() {
        // Mirrors the Python's forgiving substring detection.
        for line in [
            "// Apache License, Version 2.0",
            "// Apache-2.0",
            "// SPDX-License-Identifier: Apache-2.0",
            "// APACHE license v2.0",
        ] {
            let source = line + "\nfunc helper() -> Int { 0 }"
            #expect(Lint.Rule.`license header Tests`.findings(in: source).isEmpty)
        }
    }

    @Test
    func `apache without version is flagged`() {
        let source = "// Apache License\nfunc helper() -> Int { 0 }"
        #expect(Lint.Rule.`license header Tests`.findings(in: source).count == 1)
    }

    @Test
    func `header beyond line 30 is flagged`() {
        let filler = Swift.Array(repeating: "// filler", count: 30).joined(separator: "\n")
        let source = filler + "\n// Licensed under Apache License v2.0\nfunc helper() -> Int { 0 }"
        #expect(Lint.Rule.`license header Tests`.findings(in: source).count == 1)
    }

    @Test
    func `header on exactly line 30 is accepted`() {
        let filler = Swift.Array(repeating: "// filler", count: 29).joined(separator: "\n")
        let source = filler + "\n// Licensed under Apache License v2.0\nfunc helper() -> Int { 0 }"
        #expect(Lint.Rule.`license header Tests`.findings(in: source).isEmpty)
    }
}

extension Lint.Rule.`license header Tests`.Exemption {
    @Test
    func `Tests files are exempt`() {
        let findings = Lint.Rule.`license header Tests`.findings(
            in: "func helper() -> Int { 0 }",
            path: "Tests/Example Tests/Example Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Package manifest is exempt`() {
        let findings = Lint.Rule.`license header Tests`.findings(
            in: "// no header",
            path: "Package.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `versioned Package manifest is exempt`() {
        let findings = Lint.Rule.`license header Tests`.findings(
            in: "// no header",
            path: "Package@swift-6.3.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `paths outside Sources are exempt`() {
        // The Python anchors `parts[0] == "Sources"` at the package
        // root; the rule mirrors that anchor at the run root.
        let findings = Lint.Rule.`license header Tests`.findings(
            in: "func helper() -> Int { 0 }",
            path: "Plugins/Example/Example.swift"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`license header Tests`.`Edge Case` {
    @Test
    func `nested Sources path is covered`() {
        let findings = Lint.Rule.`license header Tests`.findings(
            in: "func helper() -> Int { 0 }",
            path: "Sources/Example/Nested/Deep/File.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `applicability predicate mirrors the Python exclusions`() {
        #expect(structureLicenseHeaderApplies(toPath: "Sources/A/B.swift"))
        #expect(!structureLicenseHeaderApplies(toPath: "Tests/A/B.swift"))
        #expect(!structureLicenseHeaderApplies(toPath: "Package.swift"))
        #expect(!structureLicenseHeaderApplies(toPath: "Package@swift-6.swift"))
        #expect(!structureLicenseHeaderApplies(toPath: "Sources/A/B.md"))
        #expect(!structureLicenseHeaderApplies(toPath: "README.swift"))
    }
}
