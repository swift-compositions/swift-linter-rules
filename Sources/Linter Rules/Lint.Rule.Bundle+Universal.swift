public import Linter_Primitives
import Linter_Rule_Idiom
import Linter_Rule_Memory
import Linter_Rule_Package
import Linter_Rule_ResultBuilder
import Linter_Rule_Structure
import Linter_Rule_Suppression
import Linter_Rule_Testing

extension Lint.Rule.Bundle {

    public static let universal: [Lint.Rule.Configuration] = [

        .enable(.`redundant refinement`),

        .enable(.`unchecked sendable categorization`),
        .enable(.`unchecked sendable noncopyable`),
        .enable(.`unsafe storage visibility`),

        .enable(.`target import edge`),

        .enable(.`for loop in result builder`),

        .enable(.`inlinable internal access`),

        .enable(.`usable from inline internal import`),

        .enable(.`malformed suppression directive`),

        .enable(.`suppression reason required`, severity: .warning),

        .enable(.`mock factory zero collision`),
    ]
}
