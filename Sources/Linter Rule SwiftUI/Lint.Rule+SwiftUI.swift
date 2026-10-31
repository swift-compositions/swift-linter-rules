public import Lint
internal import Linter_Rule_Scope

extension Lint.Rule {

    public static let `toolbar hidden` = Lint.Rule(
        id: "toolbar hidden",
        default: .warning,
        controls: [
            .init(
                id: "toolbar hidden item",
                source: """
                    struct Screen: View {
                      var body: some View {
                        List { }.toolbar { ToolbarItem { Button("Edit") { }.hidden() } }
                      }
                    }
                    """,
                path: "Controls/ToolbarHidden.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "toolbar hidden visibility argument",
                source: """
                    struct Screen: View {
                      var body: some View { List { }.toolbar(.hidden, for: .navigationBar) }
                    }
                    """,
                path: "Controls/ToolbarHiddenVisibility.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.SwiftUI.observe(
            .toolbarHidden,
            identifier: "toolbar hidden",
            message: "This rule checks for `.hidden()` inside a `toolbar { }`, `ToolbarItem` or "
                + "`ToolbarItemGroup` builder, \(Lint.SwiftUI.scope) (swift-institute/Issues#153). A hidden "
                + "toolbar item still takes its slot. Fix: include or omit the item with `if` over `store` "
                + "state inside the builder."
        )
    )
}
