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

  package static let request: Swift::String = "FetchKeyRequest"

  package static let scope: Swift::String =
    "This rule checks every call of fetchAll, fetchOne, fetchCount, fetchSet, fetchCursor or "
    + "execute in a library target: it must sit lexically inside a closure passed to a database's "
    + "read, write, writeWithoutTransaction, withRollback or observe, or inside the fetch(_:) of a "
    + "FetchKeyRequest. Executable targets, `Hosts/`, tests and `… Schema` targets (migrations) are "
    + "edges and are not checked."

  package static func observe(
    _ source: borrowing Lint.Source.Parsed,
    severity: Diagnostic.Severity
  ) -> Lint.Rule.Observation {
    guard checks(source) else {
      return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
    }
    let visitor = Visitor()
    visitor.walk(source.tree)
    let findings = visitor.calls.map { call in
      let declaration = Lint.Scope.Declaration.identity(of: call)
      return Lint.Scope.record(
        at: call,
        in: source,
        severity: severity,
        identifier: identifier,
        message: "[sql edge]: `\(call.declName.baseName.text)` runs inside `\(declaration)`, "
          + "which is not an edge. \(scope) Fix: make `\(declaration)` return the swift-sql "
          + "statement, and run it where the connection is opened (`database.read { db in "
          + "try statement.fetchAll(db) }`), in an observation or in a reducer effect."
      )
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
      if let function = ancestor.as(FunctionDeclSyntax.self), fetchesRequest(function) {
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

  fileprivate static func fetchesRequest(_ function: FunctionDeclSyntax) -> Swift::Bool {
    guard function.name.text == "fetch", function.signature.parameterClause.parameters.count == 1 else {
      return false
    }
    var current: Syntax? = function.parent
    while let ancestor = current {
      if Lint.Scope.Declaration.typeComponent(of: ancestor) != nil {
        return inherited(ancestor).contains { Lint.Scope.Declaration.leaf($0.type) == request }
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

    init() {
      super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
      if let member = Lint.SQL.Edge.execution(of: node), !Lint.SQL.Edge.isEdge(Syntax(node)) {
        calls.append(member)
      }
      return .visitChildren
    }
  }
}
