import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_Package

@Suite
struct `undeclared module import Tests` {
    @Test
    func `controls hold`() {
        for outcome in Lint.Rule.`undeclared module import`.outcomes() {
            #expect(outcome.holds, "\(outcome)")
        }
    }
}
