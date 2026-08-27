import Linter
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Testing

extension Lint.Rule {
  @Suite
  struct `mock factory zero collision Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`mock factory zero collision Tests` {

  static func findings(
    in source: String,
    file: String = "/Tests/X/Test.swift"
  ) -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`mock factory zero collision`.observe(parsed, .warning).findings
  }
}

extension Lint.Rule.`mock factory zero collision Tests`.Unit {
  @Test
  func `unsafeBitCast with bare tag is flagged`() {
    let source = """
      let value = unsafeBitCast(tag, to: UnownedJob.self)
      """
    let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `unsafeBitCast with tag offset is permitted`() {
    let source = """
      let value = unsafeBitCast(tag &+ 1, to: UnownedJob.self)
      """
    let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `unsafeBitCast with regular plus offset is permitted`() {
    let source = """
      let value = unsafeBitCast(tag + 1, to: UnownedJob.self)
      """
    let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `unrelated function call is not flagged`() {
    let source = """
      let value = makeValue(tag, to: UnownedJob.self)
      """
    let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `mock factory body with bare tag is flagged`() {
    let source = """
      extension UnownedJob {
          public static func mock(_ tag: Int = 0) -> UnownedJob {
              unsafeBitCast(tag, to: UnownedJob.self)
          }
      }
      """
    let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}
