# swift-linter-rules

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Catalog of SwiftSyntax-based AST lint rules consumable by
[`swift-linter`](https://github.com/swift-compositions/swift-linter) or any
third-party tool that imports the `Linter` protocol surface.
Each rule ships as its own SwiftPM library product so consumers activate
exactly the rules they want.

## Quick Start

In your `Lint/` nested SwiftPM package (per `swift-linter`'s adoption
recipe), depend on this package and import the rule packs you want
active:

```swift
// Lint/Package.swift
.package(url: "https://github.com/swift-compositions/swift-linter-rules.git", branch: "main"),
```

> Pre-1.0: no version tags yet. APIs may change; pin a commit for reproducible builds.

```swift
// Lint/Sources/Lint/main.swift
import Linter
import Linter_Rule_Unchecked
import Linter_Rule_Cardinal

let manifest = Lint.Manifest(
    enabledRuleIDs: [
        Lint.Rule.Unchecked.id,
        Lint.Rule.Cardinal.Count.id,
    ]
)
```

`swift run swift-linter <package>` builds the `Lint/` package and runs
the activated rules against your sources.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-compositions/swift-linter-rules.git", branch: "main"),
]
```

> Pre-1.0: no version tags yet. APIs may change; pin a commit for reproducible builds.

```swift
.target(
    name: "Lint",
    dependencies: [
        .product(name: "Linter Rule Cardinal", package: "swift-linter-rules"),
        // ... additional rule pack products
    ]
)
```

## Rule catalog

Each pack ships as its own SwiftPM product. Activate per-rule via the
`Lint.Manifest`'s `enabledRuleIDs` list.

| Pack product | Rule ID | What it catches |
|---|---|---|
| `Linter Rule Unchecked` | `` `unchecked call site` `` | `__unchecked:` argument labels at call sites that bypass the typed-system contract |
| `Linter Rule Cardinal` | `` `zero or one literal` `` | `Cardinal(0)` / `Cardinal(1)` constructor calls (use the typed `.zero` / `.one` accessors instead) |
| `Linter Rule Cardinal` | `` `count minus one` `` | `count - 1` and its semantically-equivalent rewrites — operand-reorder, paren-wrap, cast-outside |
| `Linter Rule RawValue` | `` `chained rawvalue access` `` | Chained `.rawValue.method()` patterns that escape the typed wrapper |
| `Linter Rule RawValue` | `` `bitpattern rawvalue chain` `` | Bit-pattern conversions chaining `.rawValue` |
| `Linter Rule ResultBuilder` | `` `for loop in result builder` `` | `for i in 0..<N { i }` style integer loops in builder bodies |
| `Linter Rule Try` | `` `try optional` `` | `try?` sites that swallow typed-throws errors silently |
| `Linter Rule Throws` | `` `untyped throws` `` | `throws` declarations without a typed-throws clause |
| `Linter Rule Throws` | `` `existential throws` `` | `throws(any Error)` existential-error declarations |
| `Linter Rule Naming` | `` `variable named impl` `` | Local bindings named `impl` (use the type's own name) |
| `Linter Rule Naming` | `` `property named flags` `` | `OptionSet` types named `*.Flags` (use `*.Options`) |
| `Linter Rule Naming` | `` `compound identifier` `` | Compound type, method, or property names that should decompose into nested forms |
| `Linter Rule Naming` | `` `tag suffix` `` | Phantom-type tags suffixed with `Tag` (use the bare concept name) |
| `Linter Rule SQL` | `` `sql label` `` | Call arguments labelled `sql:` |
| `Linter Rule SQL` | `` `sql string` `` | String literals whose trimmed text begins with an SQL statement keyword (upper-case, or any case with an SQL clause word); a direct `#sql` argument is exempt |
| `Linter Rule SQL` | `` `sql registry` `` | `#sql` sites outside a `… Schema` target that are not listed in `Lint.SQL.Exceptions`, stale entries, and reasons without a one-line text or a required `swift-compositions/swift-sql#<n>` link (it checks that a reason is present, not that it is sound) |
| `Linter Rule SwiftUI` | `` `with animation` `` | `withAnimation` in `View` conformers and their extensions |
| `Linter Rule SwiftUI` | `` `animation modifier` `` | `.animation(_:value:)`, `.animation(_:)`, `Binding.animation(_:)` in views |
| `Linter Rule SwiftUI` | `` `state identity` `` | `.id(_:)` whose argument is not a literal or static member |
| `Linter Rule SwiftUI` | `` `toolbar hidden` `` | `.hidden()` inside `toolbar { }`, `ToolbarItem`, `ToolbarItemGroup` (swift-institute/Issues#153) |
| `Linter Rule SwiftUI` | `` `view state` `` | `@State`, `@StateObject`, `@ObservedObject`, `@AppStorage`, `@SceneStorage`, `@Observable`-class and stored-closure view properties |
| `Linter Rule SwiftUI` | `` `view logic` `` | Sequence algorithms, Set/Dictionary construction, `Task`, lifecycle modifiers, `Date()`/`UUID()`, `UserDefaults`, `FileManager`, `Store(`, `store.modify` in views |
| `Linter Rule Feature` | `` `feature user defaults` `` | `UserDefaults`, `@AppStorage`, `.appStorage` in `@Feature` types and `… Feature` targets |
| `Linter Rule Feature` | `` `feature with animation` `` | `withAnimation` in `@Feature` types and `… Feature` targets |

The SQL, SwiftUI and Feature packs are activated from a root `Lint.swift`; the
SQL registry lives there as a Swift value:

```swift
// swift-linter-tools-version: 0.1

import Linter
import Linter_Rule_Feature
import Linter_Rule_SQL
import Linter_Rule_SwiftUI

Lint.run(dependencies: [
    .package(
        url: "https://github.com/swift-compositions/swift-linter-rules.git",
        branch: "main",
        products: ["Linter Rule SQL", "Linter Rule SwiftUI", "Linter Rule Feature"]
    ),
]) {
    Lint.Rule.Bundle.sql(exceptions: [
        .init(
            file: "Sources/Affairs SQLite/Library+SQLite.swift",
            declaration: "Library.conditions(for:)",
            sites: 2,
            reason: "mailbox predicates interpolate a JSON path that the builders cannot express yet"
        ),
    ])
    Lint.Rule.Bundle.swiftUI
    Lint.Rule.Bundle.feature
}
```

An entry names the file relative to the package root, the enclosing declaration
exactly as the `sql registry` finding reports it, the number of `#sql` sites in
that declaration, and a one-line reason.

Each rule's source carries inline documentation describing its AST
predicate, the source patterns it covers, and the convention it enforces.

## Authoring third-party rule packs

Every rule pack — institute-canonical or third-party — implements the
same protocol surface from
[`swift-linter`](https://github.com/swift-molecules/swift-linter).
A minimal third-party rule pack is one library product with a type
conforming to `Lint.Rule.Protocol`:

```swift
// Sources/MyRule/MyRule.swift
public import Linter
internal import SwiftSyntax

extension Lint.Rule {
    public struct MyRule: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "my_rule"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            // Walk the AST, return findings for matching sites.
            return []
        }
    }
}
```

Consumers depend on your package alongside `swift-linter-rules` and
import your rule pack the same way:

```swift
// Lint/Sources/Lint/main.swift
import Linter
import Linter_Rule_Cardinal       // institute-canonical pack
import MyRule                      // third-party pack

let manifest = Lint.Manifest(
    enabledRuleIDs: [
        Lint.Rule.Cardinal.Count.id,
        Lint.Rule.MyRule.id,
    ]
)
```

The `swift-linter` driver makes no distinction between canonical and
third-party packs — both flow through the same `Lint.Manifest`
activation mechanism.

## Consumers

- [`swift-linter`](https://github.com/swift-compositions/swift-linter) —
  the CLI driver and reporter shell.
- Any third-party tooling that wants the same rule predicates without the
  swift-linter executable (the predicates are pure functions over a
  `SourceFileSyntax`).

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
