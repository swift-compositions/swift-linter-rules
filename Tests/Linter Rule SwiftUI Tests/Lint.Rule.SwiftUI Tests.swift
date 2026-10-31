import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_SwiftUI

@Suite
struct `SwiftUI Tests` {
    @Suite struct `Toolbar Hidden` {}
    @Suite struct Integration {}
}

extension `SwiftUI Tests` {
    static func findings(
        _ rule: Lint.Rule,
        _ source: Swift::String,
        file: Swift::String = "Sources/Laurie SwiftUI/Screen.swift"
    ) -> [Diagnostic.Record] {
        rule.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }

    static func view(_ body: Swift::String) -> Swift::String {
        """
        struct Screen: View {
          let store: StoreOf<Feature>
          var body: some View {
            \(body)
          }
        }
        """
    }
}

extension `SwiftUI Tests`.`Toolbar Hidden` {
    @Test
    func `hidden inside toolbar builders fires`() {
        let source = `SwiftUI Tests`.view(
            """
            List { }
                  .toolbar { Button("A") { }.hidden() }
                  .toolbar(content: { ToolbarItem { Text("B").hidden() } })
                ToolbarItemGroup(placement: .primaryAction) { Text("C").hidden() }
            """
        )
        #expect(`SwiftUI Tests`.findings(.`toolbar hidden`, source).count == 3)
    }

    @Test
    func `hidden outside a toolbar and visibility argument do not fire`() {
        let source = `SwiftUI Tests`.view(
            """
            Text("A").hidden()
                List { }.toolbar(.hidden, for: .navigationBar).toolbarVisibility(.hidden)
            """
        )
        #expect(`SwiftUI Tests`.findings(.`toolbar hidden`, source).isEmpty)
    }
}

extension `SwiftUI Tests`.Integration {
    @Test
    func `controls hold for every rule`() {
        for rule in Lint.Rule.Bundle.swiftUI.map(\.rule) {
            let outcomes = rule.outcomes()
            #expect(outcomes.contains { $0.expected > 0 }, "\(rule.id)")
            for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
        }
    }
}
