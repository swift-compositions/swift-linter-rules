import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_SQL

extension Lint.Rule {
  @Suite
  struct `sql label Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`sql label Tests` {
  static func findings(_ source: Swift::String, file: Swift::String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
    Lint.Rule.`sql label`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
  }
}

extension Lint.Rule.`sql label Tests`.Unit {
  @Test
  func `call argument labelled sql fires`() {
    let findings = Lint.Rule.`sql label Tests`.findings(
      """
      func run() throws {
        try db.execute(sql: "DELETE FROM item")
        let n = try Int.fetchOne(db, sql: statement)
      }
      """
    )
    #expect(findings.count == 2)
    #expect(findings.first?.identifier == "sql label")
    #expect("\(findings.first?.location.line, default: "")" == "2")
  }

  @Test
  func `parameter declaration labelled sql does not fire`() {
    #expect(Lint.Rule.`sql label Tests`.findings("func execute(sql: String) {}").isEmpty)
  }

  @Test
  func `other labels do not fire`() {
    #expect(Lint.Rule.`sql label Tests`.findings("run(sqlText: x, query: y)").isEmpty)
  }
}

extension Lint.Rule.`sql label Tests`.`Edge Case` {
  @Test
  func `subscript and macro arguments fire`() {
    let findings = Lint.Rule.`sql label Tests`.findings(
      """
      let a = cache[sql: key]
      let b = #statement(sql: text)
      """
    )
    #expect(findings.count == 2)
  }

  @Test
  func `tuple element labelled sql does not fire`() {
    #expect(Lint.Rule.`sql label Tests`.findings("let pair = (sql: 1, other: 2)").isEmpty)
  }

  @Test
  func `a test target is exempt`() {
    #expect(Lint.Rule.`sql label Tests`.findings("run(sql: x)", file: "Tests/Affairs Tests/Store.Tests.swift").isEmpty)
  }

  @Test
  func `bare filename still fires`() {
    #expect(Lint.Rule.`sql label Tests`.findings("run(sql: x)", file: "Test.swift").count == 1)
  }

  @Test
  func `message states what it checks and the fix`() {
    let message = Lint.Rule.`sql label Tests`.findings("run(sql: x)").first?.message ?? ""
    #expect(message.contains("checks every call argument labelled `sql:`"))
    #expect(message.contains("Fix:"))
  }
}

extension Lint.Rule.`sql label Tests`.Integration {
  @Test
  func `controls hold`() {
    let outcomes = Lint.Rule.`sql label`.outcomes()
    #expect(!outcomes.isEmpty)
    #expect(outcomes.contains { $0.expected > 0 })
    for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
  }
}
