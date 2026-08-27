import Linter
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Memory

extension Lint.Rule {
  @Suite
  struct `unchecked sendable categorization Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`unchecked sendable categorization Tests` {
  static func findings(
    in source: Swift.String,
    file: Swift.String = "Sources/X/Test.swift"
  ) -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`unchecked sendable categorization`.observe(parsed, .warning).findings
  }
}

extension Lint.Rule.`unchecked sendable categorization Tests`.Unit {

  @Test
  func `unchecked Sendable without unsafe is permitted`() {
    let source = """
      final class Foo: @unchecked Sendable {}
      """
    let findings = Lint.Rule.`unchecked sendable categorization Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `unsafe unchecked Sendable on conformance is flagged`() {
    let source = """
      final class Foo: @unsafe @unchecked Sendable {}
      """
    let findings = Lint.Rule.`unchecked sendable categorization Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `plain Sendable is not flagged`() {
    let source = """
      struct Foo: Sendable {}
      """
    let findings = Lint.Rule.`unchecked sendable categorization Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `extension with unchecked Sendable without unsafe is permitted`() {
    let source = """
      extension Bar: @unchecked Sendable {}
      """
    let findings = Lint.Rule.`unchecked sendable categorization Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `extension with unsafe unchecked Sendable on conformance is flagged`() {
    let source = """
      extension Bar: @unsafe @unchecked Sendable {}
      """
    let findings = Lint.Rule.`unchecked sendable categorization Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `actor with unchecked Sendable without unsafe is permitted`() {
    let source = """
      actor Foo: @unchecked Sendable {}
      """
    let findings = Lint.Rule.`unchecked sendable categorization Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `unsafe on type declaration with unchecked Sendable on conformance is permitted`() {

    let source = """
      @unsafe
      public struct UnsafeWrapper: @unchecked Sendable {}
      """
    let findings = Lint.Rule.`unchecked sendable categorization Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}
