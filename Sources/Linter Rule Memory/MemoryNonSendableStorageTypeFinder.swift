internal import SwiftSyntax

internal final class MemoryNonSendableStorageTypeFinder: SyntaxVisitor {
    static let names: Set<Swift::String> = [
        "UnsafePointer", "UnsafeMutablePointer", "UnsafeRawPointer", "UnsafeMutableRawPointer",
        "UnsafeBufferPointer", "UnsafeMutableBufferPointer", "UnsafeRawBufferPointer",
        "UnsafeMutableRawBufferPointer", "OpaquePointer", "Unmanaged", "AnyObject",
    ]

    var found = false

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        if Self.names.contains(node.name.text) { found = true }
        return .visitChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        if Self.names.contains(node.name.text) { found = true }
        return .visitChildren
    }

    override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
        let isSendable =
            node.parent?.as(AttributedTypeSyntax.self)?.attributes.contains { element in
                guard case .attribute(let attribute) = element else { return false }
                return attribute.attributeName.trimmedDescription == "Sendable"
            } ?? false
        if !isSendable { found = true }
        return .visitChildren
    }
}
