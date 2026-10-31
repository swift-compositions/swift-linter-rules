public import Lint
public import SwiftSyntax

extension Lint.Scope {

    public static func record(
        at node: some SyntaxProtocol,
        in source: borrowing Lint.Source.Parsed,
        severity: Diagnostic.Severity,
        identifier: Swift::String,
        message: Swift::String
    ) -> Diagnostic.Record {
        let location = source.converter.location(for: node.positionAfterSkippingLeadingTrivia)
        return Diagnostic.Record(
            location: Source.Location(
                fileID: source.file.fileID,
                filePath: source.file.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: identifier,
            message: message
        )
    }
}
