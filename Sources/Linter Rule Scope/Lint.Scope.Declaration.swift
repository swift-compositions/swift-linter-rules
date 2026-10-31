public import Lint
public import SwiftSyntax

extension Lint.Scope {

    public enum Declaration {}
}

extension Lint.Scope.Declaration {

    public static let topLevel: Swift::String = "(top level)"

    public static func identity(of node: some SyntaxProtocol) -> Swift::String {
        var components: [Swift::String] = []
        var current: Syntax? = Syntax(node).parent
        while let ancestor = current {
            if let component = component(of: ancestor) {
                components.append(component)
            }
            current = ancestor.parent
        }
        guard !components.isEmpty else { return topLevel }
        return components.reversed().joined(separator: ".")
    }

    public static func qualified(type node: Syntax) -> Swift::String? {
        guard let own = typeComponent(of: node) else { return nil }
        var components: [Swift::String] = [own]
        var current: Syntax? = node.parent
        while let ancestor = current {
            if let component = typeComponent(of: ancestor) {
                components.append(component)
            }
            current = ancestor.parent
        }
        return components.reversed().joined(separator: ".")
    }

    public static func typeComponent(of node: Syntax) -> Swift::String? {
        if let decl = node.as(StructDeclSyntax.self) { return unescaped(decl.name.text) }
        if let decl = node.as(ClassDeclSyntax.self) { return unescaped(decl.name.text) }
        if let decl = node.as(EnumDeclSyntax.self) { return unescaped(decl.name.text) }
        if let decl = node.as(ActorDeclSyntax.self) { return unescaped(decl.name.text) }
        if let decl = node.as(ProtocolDeclSyntax.self) { return unescaped(decl.name.text) }
        if let decl = node.as(ExtensionDeclSyntax.self) { return typeName(decl.extendedType) }
        return nil
    }

    public static func typeName(_ type: TypeSyntax) -> Swift::String {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return unescaped(identifier.name.text)
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return typeName(member.baseType) + "." + unescaped(member.name.text)
        }
        return type.trimmedDescription
    }

    public static func leaf(_ type: TypeSyntax) -> Swift::String {
        var current = type
        while true {
            if let attributed = current.as(AttributedTypeSyntax.self) {
                current = attributed.baseType
            } else if let optional = current.as(OptionalTypeSyntax.self) {
                current = optional.wrappedType
            } else if let unwrapped = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                current = unwrapped.wrappedType
            } else {
                break
            }
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            return unescaped(identifier.name.text)
        }
        if let member = current.as(MemberTypeSyntax.self) {
            return unescaped(member.name.text)
        }
        return current.trimmedDescription
    }

    fileprivate static func component(of node: Syntax) -> Swift::String? {
        if let type = typeComponent(of: node) { return type }
        if let decl = node.as(FunctionDeclSyntax.self) {
            return unescaped(decl.name.text) + signature(decl.signature.parameterClause)
        }
        if let decl = node.as(InitializerDeclSyntax.self) {
            return "init" + signature(decl.signature.parameterClause)
        }
        if let decl = node.as(SubscriptDeclSyntax.self) {
            return "subscript" + signature(decl.parameterClause)
        }
        if node.is(DeinitializerDeclSyntax.self) {
            return "deinit"
        }
        if let decl = node.as(VariableDeclSyntax.self),
            let pattern = decl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)
        {
            return unescaped(pattern.identifier.text)
        }
        return nil
    }

    fileprivate static func signature(_ clause: FunctionParameterClauseSyntax) -> Swift::String {
        var labels = ""
        for parameter in clause.parameters {
            labels += unescaped(parameter.firstName.text) + ":"
        }
        return "(" + labels + ")"
    }

    fileprivate static func unescaped(_ text: Swift::String) -> Swift::String {
        Lint.Syntax.Identifier.unescaped(text)
    }
}
