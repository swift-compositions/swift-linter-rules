import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_Package

enum `Lint.Rule Tests` {}

extension `Lint.Rule Tests` {
    @Suite
    struct `undeclared module import Tests` {
        @Suite struct Unit {}
    }
}

extension `Lint.Rule Tests`.`undeclared module import Tests`.Unit {
    @Test
    func `controls hold`() {
        for outcome in Lint.Rule.`undeclared module import`.outcomes() {
            #expect(outcome.holds, "\(outcome)")
        }
    }
}
