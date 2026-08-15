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

@testable import Linter_Rule_Package

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif canImport(Android)
    import Android
#endif

extension Lint.Rule {
    @Suite
    struct `target import edge Tests` {
        @Suite struct Unit {}
        @Suite struct Exemption {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`target import edge Tests` {
    /// A throwaway on-disk package fixture the rule can walk.
    ///
    /// All disk
    /// access is contained POSIX, matching the pack's own reader — no
    /// filesystem package dependency.
    struct Fixture {
        let root: Swift.String

        init(manifest: Swift.String, files: [Swift.String: Swift.String]) throws(Failure) {
            var random = Swift.SystemRandomNumberGenerator()
            self.root = "/tmp/linter-rule-package-tests-\(random.next())"
            try Self.write(manifest, to: root + "/Package.swift")
            for (relative, content) in files {
                try Self.write(content, to: root + "/" + relative)
            }
        }
    }
}

extension Lint.Rule.`target import edge Tests`.Fixture {
    struct Failure: Swift.Error {
        let reason: Swift.String
    }
}

extension Lint.Rule.`target import edge Tests`.Fixture {
    fileprivate static func makeDirectories(_ raw: Swift.String) throws(Failure) {
        var prefix = ""
        for component in raw.split(separator: "/") {
            prefix += "/" + component
            guard unsafe mkdir(prefix, 0o755) == 0 || errno == EEXIST else {
                throw Failure(reason: "mkdir failed: \(prefix)")
            }
        }
    }

    fileprivate static func write(_ content: Swift.String, to raw: Swift.String) throws(Failure) {
        if let slash = raw.lastIndex(of: "/") {
            try makeDirectories(Swift.String(raw[raw.startIndex..<slash]))
        }
        guard let handle = unsafe fopen(raw, "wb") else {
            throw Failure(reason: "fopen failed: \(raw)")
        }
        defer { _ = unsafe fclose(handle) }
        let bytes = [Swift.UInt8](content.utf8)
        let written = unsafe bytes.withUnsafeBytes { pointer in
            unsafe fwrite(pointer.baseAddress, 1, pointer.count, handle)
        }
        guard written == bytes.count else {
            throw Failure(reason: "fwrite failed: \(raw)")
        }
    }

    fileprivate static func removeRecursively(_ raw: Swift.String) {
        if packageTargetImportEdgeIsDirectory(raw) {
            for name in packageTargetImportEdgeEntryNames(in: raw) {
                removeRecursively(raw + "/" + name)
            }
            _ = unsafe rmdir(raw)
        } else {
            _ = unsafe unlink(raw)
        }
    }

    fileprivate func tearDown() {
        Self.removeRecursively(root)
    }

    /// Runs the rule against the fixture's manifest.
    fileprivate func findings() throws(Failure) -> [Diagnostic.Record] {
        let manifestPath = root + "/Package.swift"
        guard let text = packageTargetImportEdgeReadText(atPath: manifestPath) else {
            throw Failure(reason: "unreadable manifest: \(manifestPath)")
        }
        let parsed = Lint.Source.parsed(
            from: text,
            file: manifestPath,
            path: Lint.Source.Path("Package.swift")
        )
        return Lint.Rule.`target import edge`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`target import edge Tests` {
    static func manifest(targets: Swift.String, dependencies: Swift.String = "") -> Swift.String {
        """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "fixture",
            dependencies: [\(dependencies)],
            targets: [\(targets)]
        )
        """
    }
}

extension Lint.Rule.`target import edge Tests`.Unit {
    @Test
    func `undeclared import is flagged`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A"),
                    .target(name: "B"),
                    """
            ),
            files: ["Sources/A/File.swift": "import B\n"]
        )
        defer { fixture.tearDown() }
        let findings = try fixture.findings()
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "target import edge")
            #expect(findings[0].message.contains("target 'A' imports 'B'"))
            #expect(findings[0].message.contains("Sources/A/File.swift:1"))
        }
    }

    @Test
    func `declared same-package target dependency is accepted`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A", dependencies: [.target(name: "B")]),
                    .target(name: "B"),
                    """
            ),
            files: ["Sources/A/File.swift": "import B\n"]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `bare-string byName dependency resolves to a same-package target`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A", dependencies: ["B"]),
                    .target(name: "B"),
                    """
            ),
            files: ["Sources/A/File.swift": "import B\n"]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `spaced target names normalize to underscored module names`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "Alpha Core", dependencies: [.target(name: "Beta Core")]),
                    .target(name: "Beta Core"),
                    """
            ),
            files: ["Sources/Alpha Core/File.swift": "import Beta_Core\n"]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `product dependency resolves member modules through a local path dep`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A", dependencies: [.product(name: "Lib", package: "dep")]),
                    """,
                dependencies: #".package(path: "dep")"#
            ),
            files: [
                "Sources/A/File.swift": "import Member\n",
                "dep/Package.swift": """
                // swift-tools-version: 6.0
                import PackageDescription
                let package = Package(
                    name: "dep",
                    products: [.library(name: "Lib", targets: ["Member"])],
                    targets: [.target(name: "Member")]
                )
                """,
            ]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `import outside a resolved product dependency is flagged`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A", dependencies: [.product(name: "Lib", package: "dep")]),
                    """,
                dependencies: #".package(path: "dep")"#
            ),
            files: [
                "Sources/A/File.swift": "import Rogue\n",
                "dep/Package.swift": """
                // swift-tools-version: 6.0
                import PackageDescription
                let package = Package(
                    name: "dep",
                    products: [.library(name: "Lib", targets: ["Member"])],
                    targets: [.target(name: "Member")]
                )
                """,
            ]
        )
        defer { fixture.tearDown() }
        let findings = try fixture.findings()
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("imports 'Rogue'"))
        }
    }

    @Test
    func `test target sources under Tests are walked`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A"),
                    .testTarget(name: "A Tests", dependencies: [.target(name: "A")]),
                    """
            ),
            files: ["Tests/A Tests/File.swift": "import A\nimport Undeclared\n"]
        )
        defer { fixture.tearDown() }
        let findings = try fixture.findings()
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("target 'A Tests' imports 'Undeclared'"))
        }
    }

    @Test
    func `explicit target path is honored`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A", path: "Custom/A"),
                    """
            ),
            files: ["Custom/A/File.swift": "import Undeclared\n"]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().count == 1)
    }
}

extension Lint.Rule.`target import edge Tests`.Exemption {
    @Test
    func `toolchain modules and underscored modules are exempt`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A"),
                    """
            ),
            files: [
                "Sources/A/File.swift": """
                import Foundation
                import Dispatch
                public import Testing
                internal import Synchronization
                import _Concurrency
                """
            ]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `own module import is exempt`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A"),
                    """
            ),
            files: ["Sources/A/File.swift": "import A\n"]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `unresolvable declared dependency degrades soft`() throws {
        // A url dep with no local checkout → the run under-reports
        // rather than false-firing (the Python's soft mode).
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A", dependencies: [.product(name: "Mystery", package: "nowhere")]),
                    """,
                dependencies:
                    #".package(url: "https://github.com/no-such-org-f9/nowhere.git", branch: "main")"#
            ),
            files: ["Sources/A/File.swift": "import CouldBeAnything\n"]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `non-manifest files never fire`() {
        let parsed = Lint.Source.parsed(
            from: "import Anything\n",
            file: "Sources/A/File.swift",
            path: Lint.Source.Path("Sources/A/File.swift")
        )
        #expect(Lint.Rule.`target import edge`.findings(parsed, .warning).isEmpty)
    }
}

extension Lint.Rule.`target import edge Tests`.`Edge Case` {
    @Test
    func `imports inside comments never match`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A"),
                    """
            ),
            files: [
                "Sources/A/File.swift": """
                // import Undeclared
                /* import AlsoUndeclared */
                let note = "see https://example.com//import Undeclared"
                """
            ]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `scoped and attributed import forms are recognized`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A"),
                    """
            ),
            files: [
                "Sources/A/File.swift": """
                @_spi(Internal) public import UndeclaredOne
                internal import struct UndeclaredTwo.Inner
                """
            ]
        )
        defer { fixture.tearDown() }
        let findings = try fixture.findings()
        #expect(findings.count == 2)
        let messages = findings.map(\.message).joined()
        #expect(messages.contains("UndeclaredOne"))
        #expect(messages.contains("UndeclaredTwo"))
    }

    @Test
    func `skip directories are pruned from the walk`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "A"),
                    """
            ),
            files: ["Sources/A/.build/Generated.swift": "import Undeclared\n"]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }

    @Test
    func `missing source directory contributes no findings`() throws {
        let fixture = try Lint.Rule.`target import edge Tests`.Fixture(
            manifest: Lint.Rule.`target import edge Tests`.manifest(
                targets: """
                    .target(name: "Ghost"),
                    """
            ),
            files: [:]
        )
        defer { fixture.tearDown() }
        #expect(try fixture.findings().isEmpty)
    }
}
