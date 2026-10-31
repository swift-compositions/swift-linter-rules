internal import SwiftParser
internal import SwiftSyntax

@usableFromInline
internal func manifestIsPackageManifest(
    _ filePath: Swift::String,
    path: Swift::String,
    text: Swift::String
) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    guard let filename = components.last else { return false }
    guard !components.dropLast().contains(where: manifestTargetTreeNames.contains) else {
        return false
    }
    guard
        filename == "Package.swift"
            || (filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift"))
    else { return false }
    // The package root's manifest is the manifest by definition. A nested file of
    // that name is one only if it reads as one: a fixture holding just a
    // tools-version line is source, as swift-linter's walker and the Institute
    // source subject treat it, and the manifest rules do not apply to it.
    guard path.split(separator: "/").filter({ $0 != "." }).count > 1 else { return true }
    return manifestRecognizes(text)
}

private let manifestTargetTreeNames: Swift::Set<Swift::Substring> = ["Sources", "Plugins"]

internal func manifestStringLiteralText(_ literal: StringLiteralExprSyntax) -> Swift::String? {
    guard literal.segments.count == 1,
        let segment = literal.segments.first,
        let stringSegment = segment.as(StringSegmentSyntax.self)
    else { return nil }
    return stringSegment.content.text
}

/// Whether `text` reads as a package manifest: it imports `PackageDescription`, or binds `package` to a `Package(…)`
/// call.
private func manifestRecognizes(_ text: Swift::String) -> Swift::Bool {
    let tree = Parser.parse(source: text)
    for item in tree.statements {
        if let declaration = item.item.as(ImportDeclSyntax.self),
            declaration.path.first?.name.text == "PackageDescription"
        {
            return true
        }
        if let declaration = item.item.as(VariableDeclSyntax.self) {
            for binding in declaration.bindings {
                guard binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "package",
                    let call = binding.initializer?.value.as(FunctionCallExprSyntax.self),
                    call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package"
                else { continue }
                return true
            }
        }
    }
    return false
}
