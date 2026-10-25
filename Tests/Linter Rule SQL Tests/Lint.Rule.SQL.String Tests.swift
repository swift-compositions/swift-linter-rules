import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_SQL

extension Lint.Rule {
  @Suite
  struct `sql string Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Exemption {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`sql string Tests` {
  static func findings(_ source: Swift::String, file: Swift::String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
    Lint.Rule.`sql string`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
  }
}

extension Lint.Rule.`sql string Tests`.Unit {
  @Test(arguments: [
    "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "PRAGMA", "WITH",
    "REPLACE", "BEGIN",
  ])
  func `every upper-case statement keyword fires`(keyword: Swift::String) {
    #expect(Lint.Rule.`sql string Tests`.findings("let s = \"\(keyword) x\"").count == 1)
  }

  @Test
  func `lower-case statement with a clause word fires`() {
    let findings = Lint.Rule.`sql string Tests`.findings(
      """
      let a = "select name from holder"
      let b = "  insert into item values (1)"
      let c = "update item set flag = 1"
      """
    )
    #expect(findings.count == 3)
  }

  @Test
  func `prose beginning with a keyword word does not fire`() {
    let findings = Lint.Rule.`sql string Tests`.findings(
      """
      let a = "Select Documents"
      let b = "With SMS"
      let c = "Select documents before refreshing local readings."
      let d = "Delete"
      """
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `keyword not at the start does not fire`() {
    let findings = Lint.Rule.`sql string Tests`.findings(
      """
      let a = "Run SELECT later"
      let b = "(SELECT 1)"
      let c = "SELECTED"
      """
    )
    #expect(findings.isEmpty)
  }
}

extension Lint.Rule.`sql string Tests`.`Edge Case` {
  @Test
  func `multi-line and raw literals fire`() {
    let findings = Lint.Rule.`sql string Tests`.findings(
      """
      let a = \"\"\"

          SELECT "id"
          FROM "item"
          \"\"\"
      let b = #"INSERT INTO "item"("id") VALUES (?)"#
      """
    )
    #expect(findings.count == 2)
  }

  @Test
  func `interpolated literal with a leading keyword fires`() {
    #expect(Lint.Rule.`sql string Tests`.findings(#"let s = "SELECT count(*) FROM \(table)""#).count == 1)
  }

  @Test
  func `literal nested in a sql macro interpolation still fires`() {
    let findings = Lint.Rule.`sql string Tests`.findings(
      #"let s = #sql("x IN (\(raw("SELECT 1")))")"#
    )
    #expect(findings.count == 1)
  }

  @Test
  func `bare filename still fires`() {
    #expect(Lint.Rule.`sql string Tests`.findings("let s = \"DROP TABLE x\"", file: "Test.swift").count == 1)
  }
}

extension Lint.Rule.`sql string Tests`.Exemption {
  @Test
  func `direct argument of sql macro is exempt`() {
    let findings = Lint.Rule.`sql string Tests`.findings(
      """
      let a = #sql("SELECT holderID FROM retrievalJoin", as: String.self)
      let b = #sql(#"PRAGMA quick_check"#)
      """
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `near miss: argument of another macro still fires`() {
    #expect(Lint.Rule.`sql string Tests`.findings(#"let a = #query("SELECT 1")"#).count == 1)
  }
}

extension Lint.Rule.`sql string Tests`.Integration {
  @Test
  func `controls hold`() {
    let outcomes = Lint.Rule.`sql string`.outcomes()
    #expect(outcomes.contains { $0.expected > 0 })
    for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
  }
}
