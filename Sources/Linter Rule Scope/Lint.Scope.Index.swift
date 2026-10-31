public import Lint
internal import SwiftParser
public import SwiftSyntax
internal import Synchronization

extension Lint.Scope {

    public struct Index: Sendable, Equatable {

        public var views: Swift::Set<Swift::String> = []

        public var representables: Swift::Set<Swift::String> = []

        public var observables: Swift::Set<Swift::String> = []

        public var features: Swift::Set<Swift::String> = []

        public init() {}
    }
}

extension Lint.Scope.Index {

    /// Views, and the modifiers and styles that draw views, which are held to the same rules.
    public static let viewProtocols: Swift::Set<Swift::String> = [
        "View", "ViewModifier", "ButtonStyle", "PrimitiveButtonStyle", "DisclosureGroupStyle", "ToggleStyle",
        "LabelStyle", "LabeledContentStyle", "GroupBoxStyle", "MenuStyle", "ProgressViewStyle", "ControlGroupStyle",
    ]

    /// Macros that make the type they are attached to a view, as TCA26's `@View(Feature.self)` does.
    public static let viewMacros: Swift::Set<Swift::String> = ["View"]

    public static let representableProtocols: Swift::Set<Swift::String> = [
        "UIViewRepresentable", "NSViewRepresentable",
    ]

    public mutating func formUnion(_ other: Self) {
        views.formUnion(other.views)
        representables.formUnion(other.representables)
        observables.formUnion(other.observables)
        features.formUnion(other.features)
    }

    public init(tree: SourceFileSyntax) {
        let collector = Collector()
        collector.walk(tree)
        self = collector.index
    }

    public static func matches(
        _ name: Swift::String,
        in names: Swift::Set<Swift::String>
    ) -> Swift::Bool {
        if names.contains(name) { return true }
        for candidate in names {
            if candidate.hasSuffix("." + name) || name.hasSuffix("." + candidate) {
                return true
            }
        }
        return false
    }

    public static func of(_ source: borrowing Lint.Source.Parsed) -> Self {
        var index = Self(tree: source.tree)
        if let root = Lint.Scope.File.root(of: source) {
            index.formUnion(cached(root: root))
        }
        return index
    }

    fileprivate static let cache = Mutex<[Swift::String: Lint.Scope.Index]>([:])

    fileprivate static func cached(root: Swift::String) -> Self {
        if let hit = cache.withLock({ $0[root] }) { return hit }
        var index = Self()
        for path in Lint.Scope.File.swiftFiles(under: root) {
            guard let text = Lint.Scope.File.text(at: path) else { continue }
            index.formUnion(Self(tree: Parser.parse(source: text)))
        }
        cache.withLock { $0[root] = index }
        return index
    }
}

extension Lint.Scope.Index {

    public static func conforms(
        _ clause: InheritanceClauseSyntax?,
        to protocols: Swift::Set<Swift::String>
    ) -> Swift::Bool {
        guard let clause else { return false }
        for inherited in clause.inheritedTypes {
            let type = inherited.type
            if let identifier = type.as(IdentifierTypeSyntax.self),
                protocols.contains(identifier.name.text)
            {
                return true
            }
            if let member = type.as(MemberTypeSyntax.self),
                protocols.contains(member.name.text),
                member.baseType.trimmedDescription == "SwiftUI"
            {
                return true
            }
        }
        return false
    }

    public static func attributed(
        _ attributes: AttributeListSyntax,
        _ names: Swift::Set<Swift::String>
    ) -> Swift::Bool {
        for element in attributes {
            guard let attribute = element.as(AttributeSyntax.self) else { continue }
            let name = Lint.Scope.Declaration.leaf(attribute.attributeName)
            if names.contains(name) { return true }
        }
        return false
    }
}

extension Lint.Scope.Index {

    fileprivate final class Collector: SyntaxVisitor {
        var index = Lint.Scope.Index()

        init() {
            super.init(viewMode: .sourceAccurate)
        }

        func record(
            _ node: some DeclSyntaxProtocol,
            inheritance: InheritanceClauseSyntax?,
            attributes: AttributeListSyntax,
            isClass: Swift::Bool
        ) {
            guard let name = Lint.Scope.Declaration.qualified(type: Syntax(node)) else { return }
            if Lint.Scope.Index.conforms(inheritance, to: Lint.Scope.Index.viewProtocols)
                || Lint.Scope.Index.attributed(attributes, Lint.Scope.Index.viewMacros)
            {
                index.views.insert(name)
            }
            if Lint.Scope.Index.conforms(inheritance, to: Lint.Scope.Index.representableProtocols) {
                index.representables.insert(name)
            }
            if isClass, Lint.Scope.Index.attributed(attributes, ["Observable"]) {
                index.observables.insert(name)
            }
            if Lint.Scope.Index.attributed(attributes, ["Feature"]) {
                index.features.insert(name)
            }
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            record(node, inheritance: node.inheritanceClause, attributes: node.attributes, isClass: false)
            return .visitChildren
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            record(node, inheritance: node.inheritanceClause, attributes: node.attributes, isClass: true)
            return .visitChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            record(node, inheritance: node.inheritanceClause, attributes: node.attributes, isClass: false)
            return .visitChildren
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            record(node, inheritance: node.inheritanceClause, attributes: node.attributes, isClass: false)
            return .visitChildren
        }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            record(node, inheritance: node.inheritanceClause, attributes: node.attributes, isClass: false)
            return .visitChildren
        }
    }
}
