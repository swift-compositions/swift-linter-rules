import Lint
import Linter_Rule_Scope
import Linter_Rules_Test_Support
import SwiftSyntax
import Testing

@testable import Linter_Rule_SwiftUI

@Suite
struct `SwiftUI Tests` {
    @Suite struct `Toolbar Hidden` {}
    @Suite struct Scope {}
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

extension `SwiftUI Tests`.Scope {
    /// What a view holds, its modifiers and styles hold too: each draws a view and is held to the same rules.
    @Test
    func `view modifiers and styles are checked as views are`() {
        let declarations = [
            "struct Highlight: ViewModifier {\n  @State var on = false\n  func body(content: Content) -> some View { content }\n}",
            "struct Row: ButtonStyle {\n  @State var on = false\n  func makeBody(configuration: Configuration) -> some View { configuration.label }\n}",
            "struct Panel: DisclosureGroupStyle {\n  @State var on = false\n  func makeBody(configuration: Configuration) -> some View { configuration.label }\n}",
        ]
        for declaration in declarations {
            let source = Lint.Source.parsed(from: declaration, file: "Sources/Laurie SwiftUI/Style.swift")
            let visitor = Lint.SwiftUI.Visitor(index: Lint.Scope.Index.of(source))
            visitor.walk(source.tree)
            #expect(visitor.hits.contains { $0.kind == .viewState }, "\(declaration)")
        }
    }
}
