package import Lint
internal import Linter_Rule_Scope
package import SwiftSyntax

extension Lint.SQL {

  package enum Edge {}
}

extension Lint.SQL.Edge {

  package static let identifier: Swift::String = "sql edge"

  /// The closed set of execution calls (swift-institute/Issues#177).
  package static let executions: Swift::Set<Swift::String> = [
    "fetchAll", "fetchOne", "fetchCount", "fetchSet", "fetchCursor", "execute",
  ]

  /// Calls whose closure argument is an edge: the closure receives a connection from the database.
  package static let edges: Swift::Set<Swift::String> = [
    "read", "write", "writeWithoutTransaction", "withRollback", "observe",
  ]

  /// The edge types and the one method each runs statements in: a read's `FetchKeyRequest.fetch(_:)` and a write's
  /// `SQLite.Transaction.run(_:)`.
  package static let requests: [Swift::String: Swift::String] = ["FetchKeyRequest": "fetch", "Transaction": "run"]

  /// Builder methods: in the receiver of an execution call outside a `… SQL` or `… Schema` target, a statement is
  /// being written at the edge instead of named where it cannot run.
  package static let builders: Swift::Set<Swift::String> = [
    "where", "select", "join", "leftJoin", "rightJoin", "fullJoin", "order", "group", "having", "limit", "distinct",
    "insert", "update", "delete", "upsert",
  ]

  package static let scope: Swift::String =
    "This rule checks every call of fetchAll, fetchOne, fetchCount, fetchSet, fetchCursor or "
    + "execute in a library target: it must sit lexically inside a closure passed to a database's "
    + "read, write, writeWithoutTransaction, withRollback or observe, inside the fetch(_:) of a "
    + "FetchKeyRequest or the run(_:) of an SQLite.Transaction; and the statement it runs must be named, "
    + "not built there with where, select, join, order, insert, update or delete. Executable targets, "
    + "`Hosts/`, tests and `… Schema` targets (migrations) are edges and are not checked."

  package static func observe(
    _ source: borrowing Lint.Source.Parsed,
    severity: Diagnostic.Severity
  ) -> Lint.Rule.Observation {
    guard checks(source) else {
      return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
    }
    let visitor = Visitor()
    visitor.walk(source.tree)
    var findings: [Diagnostic.Record] = visitor.calls.map { call in
      let declaration = Lint.Scope.Declaration.identity(of: call)
      return Lint.Scope.record(
        at: call,
        in: source,
        severity: severity,
        identifier: identifier,
        message: "[sql edge]: `\(call.declName.baseName.text)` runs inside `\(declaration)`, "
          + "which is not an edge. \(scope) Fix: make `\(declaration)` return the swift-sql "
          + "statement, and run it where the connection is opened (`database.read { db in "
          + "try statement.fetchAll(db) }`), in a FetchKeyRequest or SQLite.Transaction, or in a reducer effect."
      )
    }
    if !Lint.Scope.Target.named(source.path, suffix: " SQL") {
      findings += visitor.built.map { call in
        Lint.Scope.record(
          at: call,
          in: source,
          severity: severity,
          identifier: identifier,
          message: "[sql edge]: `\(call.declName.baseName.text)` runs a statement built here. \(scope) "
            + "Fix: name the statement as a static or function in the `… SQL` target, which cannot run it, "
            + "and run that here."
        )
      }
    }
    return Lint.Rule.Observation(findings: findings, coverage: .measured)
  }

  package static func checks(_ source: borrowing Lint.Source.Parsed) -> Swift::Bool {
    let path = source.path.underlying
    let components = path.split(separator: "/", omittingEmptySubsequences: true)
    guard components.first == "Sources" else { return false }
    if Lint.Scope.Target.named(source.path, suffix: " Schema") { return false }
    if let root = Lint.Scope.File.root(of: source), let target = Lint.Scope.Target.name(of: source.path),
      Lint.Scope.File.isFile(root + "/Sources/" + target + "/main.swift")
    {
      return false
    }
    return true
  }

  /// Whether the receiver chain of `member` calls a builder method: the statement is written where it runs.
  package static func isBuilt(_ member: MemberAccessExprSyntax) -> Swift::Bool {
    var current: ExprSyntax? = member.base
    while let expression = current {
      if let call = expression.as(FunctionCallExprSyntax.self) {
        if let callee = call.calledExpression.as(MemberAccessExprSyntax.self) {
          if builders.contains(callee.declName.baseName.text) { return true }
          current = callee.base
        } else {
          current = nil
        }
      } else if let access = expression.as(MemberAccessExprSyntax.self) {
        current = access.base
      } else {
        current = nil
      }
    }
    return false
  }

  package static func execution(of node: FunctionCallExprSyntax) -> MemberAccessExprSyntax? {
    guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
      executions.contains(member.declName.baseName.text)
    else { return nil }
    return member
  }

  package static func isEdge(_ node: Syntax) -> Swift::Bool {
    var current: Syntax? = node.parent
    while let ancestor = current {
      if let closure = ancestor.as(ClosureExprSyntax.self), opensConnection(closure) {
        return true
      }
      if let function = ancestor.as(FunctionDeclSyntax.self), runsRequest(function) {
        return true
      }
      current = ancestor.parent
    }
    return false
  }

  fileprivate static func opensConnection(_ closure: ClosureExprSyntax) -> Swift::Bool {
    var call: FunctionCallExprSyntax?
    if let direct = closure.parent?.as(FunctionCallExprSyntax.self) {
      call = direct
    } else if let argument = closure.parent?.as(LabeledExprSyntax.self),
      let list = argument.parent?.as(LabeledExprListSyntax.self)
    {
      call = list.parent?.as(FunctionCallExprSyntax.self)
    } else if let trailing = closure.parent?.as(MultipleTrailingClosureElementSyntax.self) {
      call = trailing.parent?.parent?.as(FunctionCallExprSyntax.self)
    }
    guard let member = call?.calledExpression.as(MemberAccessExprSyntax.self) else { return false }
    return edges.contains(member.declName.baseName.text)
  }

  fileprivate static func runsRequest(_ function: FunctionDeclSyntax) -> Swift::Bool {
    guard function.signature.parameterClause.parameters.count == 1 else { return false }
    var current: Syntax? = function.parent
    while let ancestor = current {
      if Lint.Scope.Declaration.typeComponent(of: ancestor) != nil {
        return inherited(ancestor).contains { requests[Lint.Scope.Declaration.leaf($0.type)] == function.name.text }
      }
      current = ancestor.parent
    }
    return false
  }

  fileprivate static func inherited(_ node: Syntax) -> [InheritedTypeSyntax] {
    let clause: InheritanceClauseSyntax? =
      node.as(StructDeclSyntax.self)?.inheritanceClause
      ?? node.as(ClassDeclSyntax.self)?.inheritanceClause
      ?? node.as(EnumDeclSyntax.self)?.inheritanceClause
      ?? node.as(ActorDeclSyntax.self)?.inheritanceClause
      ?? node.as(ExtensionDeclSyntax.self)?.inheritanceClause
    return clause.map { Swift::Array($0.inheritedTypes) } ?? []
  }
}

extension Lint.SQL.Edge {

  fileprivate final class Visitor: SyntaxVisitor {
    var calls: [MemberAccessExprSyntax] = []
    var built: [MemberAccessExprSyntax] = []

    init() {
      super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
      if let member = Lint.SQL.Edge.execution(of: node) {
        if !Lint.SQL.Edge.isEdge(Syntax(node)) {
          calls.append(member)
        } else if Lint.SQL.Edge.isBuilt(member) {
          built.append(member)
        }
      }
      return .visitChildren
    }
  }
}
