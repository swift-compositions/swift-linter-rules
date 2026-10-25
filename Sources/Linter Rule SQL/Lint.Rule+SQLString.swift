public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

  public static let `sql string` = Lint.Rule(
    id: "sql string",
    default: .warning,
    controls: [
      .init(
        id: "sql string statement",
        source: """
          let statement = "SELECT name FROM holder"
          """,
        path: "Controls/SQLString.swift",
        expectation: .findings(1)
      ),
      .init(
        id: "sql string macro argument",
        source: """
          let fragment = #sql("SELECT 1")
          let title = "Select Documents"
          """,
        path: "Controls/SQLStringMacro.swift",
        expectation: .clean
      ),
    ],
    observe: { source, severity in
      guard !Lint.Scope.Target.isTest(source.path) else {
        return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
      }
      let visitor = SQLStringVisitor()
      visitor.walk(source.tree)
      let findings = visitor.literals.map { literal in
        Lint.Scope.record(
          at: literal,
          in: source,
          severity: severity,
          identifier: "sql string",
          message: `sql string message`
        )
      }
      return Lint.Rule.Observation(findings: findings, coverage: .measured)
    }
  )
}

package let `sql string message`: Swift::String =
  "[sql string]: checks string literals (single-line, multi-line or raw) whose trimmed text begins "
  + "with an SQL statement keyword (SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, PRAGMA, "
  + "WITH, REPLACE, BEGIN): an upper-case keyword always matches; a keyword in any other case matches "
  + "when the literal also contains FROM, INTO, VALUES, WHERE, SET, TABLE, INDEX, TRIGGER or "
  + "TRANSACTION. SQL in a String value is not checked against the schema. Fix: build the statement "
  + "with swift-sql; a literal that is a direct argument of `#sql` is exempt here and governed by "
  + "`sql registry` instead."

internal final class SQLStringVisitor: SyntaxVisitor {
  var literals: [StringLiteralExprSyntax] = []

  init() {
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
    if !Lint.SQL.Statement.isDirectArgumentOfSQLMacro(node),
      Lint.SQL.Statement.leads(Lint.SQL.Statement.text(of: node))
    {
      literals.append(node)
    }
    return .visitChildren
  }
}
