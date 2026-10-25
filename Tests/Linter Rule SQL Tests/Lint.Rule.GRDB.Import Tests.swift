import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_SQL

extension Lint.Rule {
  @Suite
  struct `grdb import Tests` {
    @Suite struct Unit {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`grdb import Tests` {
  static func findings(_ source: Swift::String, file: Swift::String = "Sources/Affairs SQLite/Store.swift") -> [Diagnostic.Record] {
    Lint.Rule.`grdb import`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
  }
}

extension Lint.Rule.`grdb import Tests`.Unit {
  @Test(arguments: [
    "import GRDB",
    "public import GRDB",
    "@_exported import GRDB",
    "import struct GRDB.DatabaseQueue",
    "@testable import GRDB",
  ])
  func `every import of GRDB fires`(source: Swift::String) {
    #expect(Lint.Rule.`grdb import Tests`.findings(source).count == 1)
  }

  @Test
  func `other imports do not fire`() {
    #expect(Lint.Rule.`grdb import Tests`.findings("import SQLite\nimport GRDBQuery\nimport SQL").isEmpty)
  }

  @Test
  func `manifest names of the GRDB package fire`() {
    let findings = Lint.Rule.`grdb import Tests`.findings(
      """
      let package = Package(
        dependencies: [.package(url: "https://github.com/groue/GRDB.swift", from: "7.6.0")],
        targets: [.target(name: "A", dependencies: [.product(name: "GRDB", package: "GRDB.swift")])]
      )
      """,
      file: "Package.swift"
    )
    #expect(findings.count == 2)
  }

  @Test
  func `the same strings outside a manifest do not fire`() {
    #expect(Lint.Rule.`grdb import Tests`.findings(#"let name = "GRDB.swift""#).isEmpty)
  }
}

extension Lint.Rule.`grdb import Tests`.Integration {
  @Test
  func `controls hold`() {
    let outcomes = Lint.Rule.`grdb import`.outcomes()
    #expect(outcomes.contains { $0.expected > 0 })
    for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
  }
}
