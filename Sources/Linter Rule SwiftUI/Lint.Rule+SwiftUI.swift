public import Lint
internal import Linter_Rule_Scope

extension Lint.Rule {

  public static let `with animation` = Lint.Rule(
    id: "with animation",
    default: .warning,
    controls: [
      .init(
        id: "with animation in view",
        source: """
          struct Row: View {
            let store: StoreOf<Feature>
            var body: some View {
              Button("Flag") { withAnimation { store.send(.flagTapped) } }
            }
          }
          """,
        path: "Controls/WithAnimation.swift",
        expectation: .findings(1)
      ),
      .init(
        id: "with animation outside view",
        source: """
          struct Model {
            func run() { withAnimation { } }
          }
          """,
        path: "Controls/WithAnimationModel.swift",
        expectation: .clean
      ),
    ],
    observe: Lint.SwiftUI.observe(
      .withAnimation,
      identifier: "with animation",
      message: "This rule checks for `withAnimation` calls \(Lint.SwiftUI.scope). A view does "
        + "not drive animation imperatively. Fix: send the action (`store.send(.case)`); a change "
        + "that comes from the database animates through the feature's `Observing(...).animation()`, "
        + "other state animates through the feature (TCA26); the view declares only `.transition`, "
        + "`.contentTransition` and `.symbolEffect`."
    )
  )

  public static let `animation modifier` = Lint.Rule(
    id: "animation modifier",
    default: .warning,
    controls: [
      .init(
        id: "animation modifier value and binding",
        source: """
          struct Row: View {
            @Bindable var store: StoreOf<Feature>
            var body: some View {
              Toggle("Flag", isOn: $store.flagged.animation())
                .animation(.default, value: store.flagged)
            }
          }
          """,
        path: "Controls/AnimationModifier.swift",
        expectation: .findings(2)
      ),
      .init(
        id: "animation modifier transition",
        source: """
          struct Row: View {
            var body: some View { Text("A").transition(.opacity) }
          }
          """,
        path: "Controls/AnimationModifierTransition.swift",
        expectation: .clean
      ),
    ],
    observe: Lint.SwiftUI.observe(
      .animationModifier,
      identifier: "animation modifier",
      message: "This rule checks for `.animation(_:value:)`, `.animation(_:)` and "
        + "`Binding.animation(_:)` (`$x.animation(…)`) \(Lint.SwiftUI.scope). Fix: remove it; the "
        + "feature owns animation (`Observing(...).animation()` for database changes, TCA26 for "
        + "state that never touches the database), a binding sends its action unanimated, and the "
        + "view keeps only `.transition`, `.contentTransition` and `.symbolEffect`."
    )
  )

  public static let `state identity` = Lint.Rule(
    id: "state identity",
    default: .warning,
    controls: [
      .init(
        id: "state identity driven by state",
        source: """
          struct Detail: View {
            let store: StoreOf<Feature>
            var body: some View { Text(store.title).id(store.document) }
          }
          """,
        path: "Controls/StateIdentity.swift",
        expectation: .findings(1)
      ),
      .init(
        id: "state identity static member",
        source: """
          struct Detail: View {
            var body: some View { Text("A").id(Anchor.top).id("header").id(.bottom) }
          }
          """,
        path: "Controls/StateIdentityStatic.swift",
        expectation: .clean
      ),
    ],
    observe: Lint.SwiftUI.observe(
      .stateIdentity,
      identifier: "state identity",
      message: "This rule checks `.id(_:)` whose argument is neither a literal nor a static "
        + "member, \(Lint.SwiftUI.scope). Identity driven by state discards the view's identity on "
        + "every change, so rows cannot move and transitions replay. Fix: drop the `.id`, or use a "
        + "literal or static member; let `ForEach` identity follow each row's own `id`."
    )
  )

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

  public static let `view state` = Lint.Rule(
    id: "view state",
    default: .warning,
    controls: [
      .init(
        id: "view state wrapper and closure",
        source: """
          struct Row: View {
            @State var expanded = false
            let onTap: () -> Void
            var body: some View { Text("A") }
          }
          """,
        path: "Controls/ViewState.swift",
        expectation: .findings(2)
      ),
      .init(
        id: "view state allowed properties",
        source: """
          struct Row: View {
            @Bindable var store: StoreOf<Feature>
            @Namespace var namespace
            @FocusState var focused: Bool
            var body: some View { Text("A") }
          }
          """,
        path: "Controls/ViewStateAllowed.swift",
        expectation: .clean
      ),
    ],
    observe: Lint.SwiftUI.observe(
      .viewState,
      identifier: "view state",
      message: "This rule checks view properties declared with `@State`, `@StateObject`, "
        + "`@ObservedObject`, `@AppStorage` or `@SceneStorage`, properties whose type is an "
        + "`@Observable` class declared in this package, and stored properties of function type, "
        + "\(Lint.SwiftUI.scope). A view holds no state. Fix: move the state into the feature's "
        + "`State` and read it through `store`; replace a stored closure with `store.send(.case)`; "
        + "anything persisted lives in SQLite."
    )
  )

  public static let `view logic` = Lint.Rule(
    id: "view logic",
    default: .warning,
    controls: [
      .init(
        id: "view logic algorithm and lifecycle",
        source: """
          struct List: View {
            let store: StoreOf<Feature>
            var body: some View {
              ForEach(store.rows.filter(\\.visible)) { Text($0.title) }
                .onAppear { store.send(.appeared) }
            }
          }
          """,
        path: "Controls/ViewLogic.swift",
        expectation: .findings(2)
      ),
      .init(
        id: "view logic store reads",
        source: """
          struct List: View {
            let store: StoreOf<Feature>
            var body: some View {
              ForEach(store.rows) { row in Text(row.title) }
              Button("Done") { store.send(.doneTapped) }
            }
          }
          """,
        path: "Controls/ViewLogicStore.swift",
        expectation: .clean
      ),
    ],
    observe: Lint.SwiftUI.observe(
      .viewLogic,
      identifier: "view logic",
      message: "This rule checks calls to filter, sorted, sort, reduce, map, compactMap, flatMap, "
        + "first(where:), last(where:), contains(where:), min, max and allSatisfy (including "
        + "`.map` passed to `ForEach`); Set and Dictionary construction; `Task`; the `.task`, "
        + "`.onAppear`, `.onDisappear`, `.onChange` and `.onReceive` modifiers; `Date()`, "
        + "`Date.now`, `UUID()`, `UserDefaults` and `FileManager`; `Store(` initialisation; and "
        + "`store.modify` — \(Lint.SwiftUI.scope). Fix: compute it in SQL (a `@Selection` with "
        + "exactly the columns the row shows) or in the feature, and have the view read `store` "
        + "members and send actions."
    )
  )
}
