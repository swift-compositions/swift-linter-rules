internal import SwiftSyntax

internal func structureIsProtocolSentinelName(_ name: Swift.String) -> Swift.Bool {
    return name == "Protocol" || name == "`Protocol`"
}

@usableFromInline
internal let structureSyntaxVisitorFamilyNames: Swift.Set<Swift.String> = [
    "SyntaxVisitor",
    "SyntaxAnyVisitor",
    "SyntaxRewriter",
]

internal func structureExtendsSyntaxVisitor(_ clause: InheritanceClauseSyntax?) -> Swift.Bool {
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
        let type = inherited.type
        let leaf: Swift.String?
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            leaf = identifier.name.text
        } else if let member = type.as(MemberTypeSyntax.self) {
            leaf = member.name.text
        } else {
            leaf = nil
        }
        if let leaf, structureSyntaxVisitorFamilyNames.contains(leaf) {
            return true
        }
    }
    return false
}
