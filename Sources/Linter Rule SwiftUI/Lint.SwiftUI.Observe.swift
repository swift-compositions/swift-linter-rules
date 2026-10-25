package import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.SwiftUI {

  package static let scope: Swift::String =
    "in types conforming to `View` and in extensions of them (types conforming to "
    + "`UIViewRepresentable` or `NSViewRepresentable`, and their `Coordinator`, are exempt)"

  package static func observe(
    _ kind: Kind,
    identifier: Swift::String,
    message: Swift::String
  ) -> @Sendable (borrowing Lint.Source.Parsed, Diagnostic.Severity) -> Lint.Rule.Observation {
    Lint.Rule.measured { source, severity in
      let visitor = Visitor(index: Lint.Scope.Index.of(source))
      visitor.walk(source.tree)
      return visitor.hits.filter { $0.kind == kind }.map { hit in
        Lint.Scope.record(
          at: hit.node,
          in: source,
          severity: severity,
          identifier: identifier,
          message: "[\(identifier)]: \(hit.detail). \(message)"
        )
      }
    }
  }
}
