internal import SwiftSyntax

internal func memoryWhereClauseHasPositiveCopyable(
    _ clause: GenericWhereClauseSyntax?
) -> Swift.Bool {
    guard let clause else { return false }
    for requirement in clause.requirements {
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        if memoryTypeMentionsPositiveCopyable(conformance.rightType) {
            return true
        }
    }
    return false
}

internal func memoryTypeMentionsPositiveCopyable(_ type: TypeSyntax) -> Swift.Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Copyable"
    {
        return true
    }
    if let member = type.as(MemberTypeSyntax.self),
        member.name.text == "Copyable",
        let base = member.baseType.as(IdentifierTypeSyntax.self),
        base.name.text == "Swift"
    {
        return true
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        for element in composition.elements {
            if memoryTypeMentionsPositiveCopyable(element.type) {
                return true
            }
        }
    }
    return false
}
