public import Lint
import Linter_Rule_Idiom
import Linter_Rule_Memory
import Linter_Rule_Package
import Linter_Rule_Platform
import Linter_Rule_Structure
import Linter_Rule_Suppression
import Linter_Rule_Testing
import Linter_Rule_Throws

extension Lint.Rule.Bundle {

    public static let universal: [Lint.Rule.Configuration] = [

        .enable(.`redundant refinement`),
        .enable(.`enumerated with subscript`, severity: .error),
        .enable(.`literal conformance shadows validating init`),

        .enable(.`unchecked sendable categorization`),
        .enable(.`unchecked sendable noncopyable`),
        .enable(.`borrowing self short circuit`, severity: .error),
        .enable(.`noncopyable error`, severity: .error),
        .enable(.`extension noncopyable constraint`),
        .enable(.`sendable struct with class member`, severity: .error),
        .enable(.`sending return conditional sendable state`, severity: .error),

        .enable(.`conflicting dependency url`),
        .enable(.`undeclared module import`),

        .enable(.`convention c representability`, severity: .error),

        .enable(.`typed throws cannot use self error`, severity: .error),

        .enable(.`inlinable internal access`, severity: .warning),

        .enable(.`usable from inline internal import`),

        .enable(.`malformed suppression directive`, severity: .error),

        .enable(.`mock factory zero collision`, severity: .error),
    ]
}
