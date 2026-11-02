package import Lint
package import SwiftSyntax

extension Lint.Rule.Package.Manifest {
    /// Reads a manifest's `Package(...)` declaration into a ``Lint.Rule.Package.Manifest``.
    package final class Reader: SyntaxVisitor {
        package var manifest: Lint.Rule.Package.Manifest

        package init() {
            manifest = Lint.Rule.Package.Manifest()
            super.init(viewMode: .sourceAccurate)
        }

        override package func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let called = node.calledExpression.as(DeclReferenceExprSyntax.self),
                called.baseName.text == "Package"
            else { return .visitChildren }
            for argument in node.arguments {
                switch argument.label?.text {
                case "products": readProducts(argument.expression)
                case "targets": readTargets(argument.expression)
                case "traits": readTraits(argument.expression)
                case "dependencies": readRequests(argument.expression)
                default: continue
                }
            }
            return .skipChildren
        }

        func readProducts(_ expression: ExprSyntax) {
            for call in Self.calls(in: expression) {
                manifest.products.formUnion(Self.strings(Self.argument("targets", of: call)))
            }
        }

        func readTargets(_ expression: ExprSyntax) {
            for call in Self.calls(in: expression) {
                guard let kind = Self.member(of: call), kind != "testTarget",
                    let name = Self.string(Self.argument("name", of: call))
                else { continue }
                manifest.understood = true
                let elements = Self.argument("dependencies", of: call)?.as(ArrayExprSyntax.self)?.elements ?? []
                manifest.targets[name] = elements.compactMap { element in Self.edge(element.expression) }
            }
        }

        func readTraits(_ expression: ExprSyntax) {
            for call in Self.calls(in: expression) {
                let implied = Self.strings(Self.argument("enabledTraits", of: call))
                switch Self.member(of: call) {
                case "default": manifest.defaults.formUnion(implied)
                case "trait":
                    if let name = Self.string(Self.argument("name", of: call)) {
                        manifest.implications[name, default: []].formUnion(implied)
                    }
                default: continue
                }
            }
        }

        func readRequests(_ expression: ExprSyntax) {
            for call in Self.calls(in: expression) where Self.member(of: call) == "package" {
                guard let url = Self.string(Self.argument("url", of: call)) else { continue }
                var request = Lint.Rule.Package.Manifest.Request()
                if let traits = Self.argument("traits", of: call)?.as(ArrayExprSyntax.self) {
                    for element in traits.elements {
                        if let name = Self.string(element.expression) {
                            request.traits.insert(name)
                        } else if let call = element.expression.as(FunctionCallExprSyntax.self),
                            let name = Self.string(Self.argument("name", of: call))
                        {
                            request.traits.insert(name)
                        } else if element.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "defaults" {
                            request.defaults = true
                        }
                    }
                } else {
                    request.defaults = true
                }
                manifest.requests[packageConflictingDependencyURLIdentity(url)] = request
            }
        }

        static func edge(_ expression: ExprSyntax) -> Lint.Rule.Package.Manifest.Edge? {
            if let name = string(expression) { return .target(name, traits: nil) }
            guard let call = expression.as(FunctionCallExprSyntax.self) else { return nil }
            let traits = argument("condition", of: call)?.as(FunctionCallExprSyntax.self)
                .flatMap { argument("traits", of: $0) }
                .map { Swift::Set(strings($0)) }
            switch member(of: call) {
            case "product":
                return string(argument("package", of: call)).map { .product(package: $0, traits: traits) }
            case "target", "byName":
                return string(argument("name", of: call)).map { .target($0, traits: traits) }
            default:
                return nil
            }
        }

        static func calls(in expression: ExprSyntax) -> [FunctionCallExprSyntax] {
            expression.as(ArrayExprSyntax.self)?.elements.compactMap { $0.expression.as(FunctionCallExprSyntax.self) } ?? []
        }

        static func member(of call: FunctionCallExprSyntax) -> Swift::String? {
            call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        }

        static func argument(_ label: Swift::String, of call: FunctionCallExprSyntax) -> ExprSyntax? {
            call.arguments.first { $0.label?.text == label }?.expression
        }

        static func string(_ expression: ExprSyntax?) -> Swift::String? {
            guard let literal = expression?.as(StringLiteralExprSyntax.self), literal.segments.count == 1 else { return nil }
            return literal.segments.first?.as(StringSegmentSyntax.self)?.content.text
        }

        static func strings(_ expression: ExprSyntax?) -> [Swift::String] {
            expression?.as(ArrayExprSyntax.self)?.elements.compactMap { string($0.expression) } ?? []
        }
    }
}
