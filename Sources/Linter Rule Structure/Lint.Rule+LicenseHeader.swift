public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {

    public static let `license header` = Lint.Rule(
        id: "license header",

        default: .warning,
        findings: { source, severity in
            guard structureLicenseHeaderApplies(toPath: Swift.String(describing: source.path))
            else {
                return []
            }
            guard !structureLicenseHeaderIsPresent(in: source.tree.description) else {
                return []
            }
            return [
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: 1,
                        column: 1
                    ),
                    severity: severity,
                    identifier: "license header",
                    message: structureLicenseHeaderMessage
                )
            ]
        }
    )
}

package let structureLicenseHeaderLineLimit: Swift.Int = 30

package let structureLicenseHeaderMessage: Swift.String =
    "[license header]: every `Sources/**/*.swift` file must carry the "
    + "Apache-2.0 license header within its first 30 lines. Add the "
    + "project's standard header block (any spelling containing "
    + "`Apache` and `2.0` is accepted — e.g. `Licensed under Apache "
    + "License v2.0`)."

package func structureLicenseHeaderApplies(toPath path: Swift.String) -> Swift.Bool {
    let parts = path.split(separator: "/").map(Swift.String.init)
    guard let name = parts.last else { return false }
    guard name.hasSuffix(".swift") else { return false }
    if name == "Package.swift" { return false }
    if name.hasPrefix("Package@") { return false }
    guard let first = parts.first else { return false }
    if first == "Tests" { return false }
    return first == "Sources"
}

package func structureLicenseHeaderIsPresent(in source: Swift.String) -> Swift.Bool {
    let head =
        source
        .split(separator: "\n", omittingEmptySubsequences: false)
        .prefix(structureLicenseHeaderLineLimit)
        .joined(separator: "\n")
        .lowercased()
    return head.contains("apache") && head.contains("2.0")
}
