public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `extension noncopyable constraint` = Lint.Rule(
        id: "extension noncopyable constraint",
        default: .warning,
        controls: [
            .init(
                id: "extension noncopyable constraint copyable implying where",
                source: "extension Container where Element: SignedNumeric { consuming func transfer() {} }",
                path: "Sources/X/Container+Numeric.swift",
                expectation: .clean
            ),
            .init(
                id: "extension noncopyable constraint same type where",
                source: "extension Container where Element == UInt { consuming func transfer() {} }",
                path: "Sources/X/Container+UInt.swift",
                expectation: .clean
            ),
            .init(
                id: "extension noncopyable constraint missing",
                source: "extension Container<Element> { consuming func transfer() {} }",
                path: "Sources/Memory Core/MissingNoncopyableConstraint.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "extension noncopyable constraint explicit",
                source: "extension Container where Element: ~Copyable { consuming func transfer() {} }",
                path: "Sources/Memory Core/ExplicitNoncopyableConstraint.swift",
                expectation: .clean
            ),
            .init(
                id: "extension noncopyable constraint no ownership",
                source: "extension Container<Element> { func describe() -> String { \"\" } }",
                path: "Sources/Memory Core/NoOwnershipSurface.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = MemoryExtensionNoncopyableConstraintVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let memoryExtensionConstraintInexpressibleTypes: Swift::Set<Swift::String> = [
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafeMutableRawPointer",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
    "Array",
    "ArraySlice",
    "ContiguousArray",
    "CollectionOfOne",
    "EmptyCollection",
    "KeyValuePairs",
    "ReversedCollection",
    "Range",
    "ClosedRange",
    "PartialRangeFrom",
    "PartialRangeThrough",
    "PartialRangeUpTo",
    "Optional",
    "Dictionary",
    "Set",
    "String",
    "Substring",
    "Result",
]

@usableFromInline
internal let memoryExtensionConstraintInexpressibleQualifiedTypes: Swift::Set<Swift::String> = []

@usableFromInline
internal let memoryExtensionNoncopyableConstraintMessage: Swift::String =
    "[extension noncopyable constraint] [MEM-COPY-004]: extensions on `~Copyable`-"
    + "aware generic types MUST include explicit `where ... ~Copyable` constraints. "
    + "Without it, the extension is implicitly `where Element: Copyable` and the "
    + "surface silently shrinks. Add `where Element: ~Copyable` (or the matching "
    + "constraint name for your type's generic parameter)."

internal final class MemoryExtensionNoncopyableConstraintVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func extendedTypeLeafName(_ type: TypeSyntax) -> Swift::String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        return nil
    }

    private func extendedTypeQualifiedName(_ type: TypeSyntax) -> Swift::String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            guard let base = extendedTypeQualifiedName(member.baseType) else {
                return nil
            }
            return "\(base).\(member.name.text)"
        }
        return nil
    }

    private func extensionTargetIsSyntacticallyNonGeneric(_ node: ExtensionDeclSyntax) -> Bool {
        if extendedTypeHasGenericArguments(node.extendedType) {
            return false
        }
        if node.genericWhereClause != nil {
            return false
        }
        return true
    }

    private func extendedTypeHasGenericArguments(_ type: TypeSyntax) -> Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.genericArgumentClause != nil
        }
        if let member = type.as(MemberTypeSyntax.self) {
            if member.genericArgumentClause != nil {
                return true
            }
            return extendedTypeHasGenericArguments(member.baseType)
        }
        return false
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if source.filePath.contains(" where ") {
            return .visitChildren
        }
        if extensionTargetIsSyntacticallyNonGeneric(node) {
            return .visitChildren
        }
        if let qualified = extendedTypeQualifiedName(node.extendedType),
            memoryExtensionConstraintInexpressibleQualifiedTypes.contains(qualified)
        {
            return .visitChildren
        }
        if let leaf = extendedTypeLeafName(node.extendedType),
            memoryExtensionConstraintInexpressibleTypes.contains(leaf)
        {
            return .visitChildren
        }
        let finder = MemoryExtensionNoncopyableOwnershipFinder(viewMode: .sourceAccurate)
        finder.walk(node.memberBlock)
        guard finder.found else {
            return .visitChildren
        }
        let packFinder = MemoryExtensionPackExpansionFinder(viewMode: .sourceAccurate)
        packFinder.walk(node)
        guard !packFinder.found else {
            return .visitChildren
        }
        guard !memoryWhereClauseHasNoncopyable(node.genericWhereClause) else {
            return .visitChildren
        }
        guard !memoryWhereClauseHasPositiveCopyable(node.genericWhereClause) else {
            return .visitChildren
        }
        guard !memoryExtensionWhereClauseExcludesNoncopyable(node.genericWhereClause) else {
            return .visitChildren
        }
        let location = converter.location(for: node.extendedType.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "extension noncopyable constraint",
                message: memoryExtensionNoncopyableConstraintMessage
            )
        )
        return .visitChildren
    }
}

/// Protocols whose conformers are always `Copyable`, so a requirement on one
/// already rules out `~Copyable` and the extension has nothing to relax.
/// `Equatable`, `Hashable` and `Comparable` are left out: they admit `~Copyable`.
private let memoryExtensionCopyableImplyingProtocols: Swift::Set<Swift::String> = [
    "AdditiveArithmetic", "Numeric", "SignedNumeric", "BinaryInteger", "FixedWidthInteger",
    "SignedInteger", "UnsignedInteger", "FloatingPoint", "BinaryFloatingPoint", "Strideable",
    "RawRepresentable", "Sequence", "Collection", "BidirectionalCollection",
    "RandomAccessCollection", "MutableCollection", "RangeReplaceableCollection",
    "StringProtocol", "Codable", "Encodable", "Decodable", "CaseIterable", "AnyObject",
]

/// A where clause that requires a `Copyable`-implying protocol, or pins a
/// parameter to a concrete type with `==`, leaves no `~Copyable` to add.
private func memoryExtensionWhereClauseExcludesNoncopyable(
    _ clause: GenericWhereClauseSyntax?
) -> Swift::Bool {
    guard let clause else { return false }
    for requirement in clause.requirements {
        if requirement.requirement.is(SameTypeRequirementSyntax.self) {
            return true
        }
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        let types: [TypeSyntax] =
            conformance.rightType.as(CompositionTypeSyntax.self).map { $0.elements.map(\.type) }
            ?? [conformance.rightType]
        let names = types.map { type in
            Swift::String(type.trimmedDescription.split(separator: ".").last ?? "")
        }
        if names.contains(where: memoryExtensionCopyableImplyingProtocols.contains) {
            return true
        }
    }
    return false
}
