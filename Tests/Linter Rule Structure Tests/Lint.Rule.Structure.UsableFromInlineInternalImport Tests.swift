import Linter_Primitives
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Structure

extension Lint.Rule {
  @Suite
  struct `usable from inline internal import Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`usable from inline internal import Tests` {
  static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`usable from inline internal import`.observe(parsed, .warning).findings
  }
}

extension Lint.Rule.`usable from inline internal import Tests`.Unit {
  @Test
  func `usableFromInline plus internal import is flagged`() {

    let source = """
      internal import OtherModule

      @usableFromInline
      func helper() -> OtherModule.Foo { fatalError() }
      """
    let findings = Lint.Rule.`usable from inline internal import Tests`.findings(in: source)
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].identifier == "usable from inline internal import")
      #expect(findings[0].severity == .warning)
    }
  }

  @Test
  func `multiple internal imports each flagged when usableFromInline present`() {

    let source = """
      internal import ModuleA
      internal import ModuleB

      @usableFromInline
      func x(_ a: ModuleA.Foo, _ b: ModuleB.Foo) {}
      """
    let findings = Lint.Rule.`usable from inline internal import Tests`.findings(in: source)
    #expect(findings.count == 2)
  }
}

extension Lint.Rule.`usable from inline internal import Tests`.`Edge Case` {
  @Test
  func `usableFromInline alone is NOT flagged`() {
    let source = """
      @usableFromInline
      func helper() -> Int { 0 }
      """
    let findings = Lint.Rule.`usable from inline internal import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `internal import alone is NOT flagged`() {
    let source = """
      internal import OtherModule

      func helper() -> Int { 0 }
      """
    let findings = Lint.Rule.`usable from inline internal import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `public import plus usableFromInline is NOT flagged`() {
    let source = """
      public import OtherModule

      @usableFromInline
      func helper() -> Int { 0 }
      """
    let findings = Lint.Rule.`usable from inline internal import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}
