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
| `Linter Rule SQL` | `` `sql fragment` `` | `#sql` outside a `… Schema` target that is a whole statement, names a table or column by a quoted identifier, or interpolates nothing |
| `Linter Rule SQL` | `` `sql edge` `` | `fetchAll`, `fetchOne`, `fetchCount`, `fetchSet`, `fetchCursor` or `execute` in a library target outside a database's `read`/`write`/`writeWithoutTransaction`/`withRollback`/`observe` closure or a `FetchKeyRequest`'s `fetch(_:)` (swift-institute/Issues#177) |
| `Linter Rule SQL` | `` `grdb import` `` | `import GRDB` in any form, and manifest strings naming the GRDB.swift package; enable everywhere except swift-sqlite |
| `Linter Rule SQL` | `` `database closure type` `` | A closure passed to `read`, `write`, `writeWithoutTransaction`, `withRollback` or `observe` that has more than one statement, returns a value and does not state its result type: inferring it from several returns is where the compiler hung on an unresolved name (swift-institute/Issues#181). Part of `Lint.Rule.Bundle.buildErrors` |
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

## Rules as build errors

Until now the rules ran only through `swift-linter`, from a `Lint.swift` at a package root, by hand or in CI. Nothing
stopped a build on a finding. `Lint.Rule.Bundle.buildErrors` is the set of rules whose findings must stop one, each
pinned to `error`, and three products run it:

| Product | What it is |
|---|---|
| `Linter Build Errors Plugin` | A SwiftPM build-tool plugin. It runs before the target compiles and prints `path:line:column: error: [rule]: message`, which Xcode and SwiftPM show as build errors. |
| `swift-linter-build-errors` | The executable the plugin runs. By hand: `swift run swift-linter-build-errors --root <directory> <file.swift> ...`. It exits 0 when clean, 1 on an error and 64 on refused arguments. |
| `Linter Rule Build Errors` | The library that holds the bundle, for a `Lint.swift`. |

The bundle holds `database closure type`. A rule joins it when a finding is a hang or a defect that must stop the build,
never when it is a matter of style. The tool reads every file it is given: a file it cannot read, and a rule that
cannot measure a file, are errors, and a `// swift-linter:disable` comment does not silence a finding.

### A SwiftPM package

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/swift-compositions/swift-linter-rules.git", branch: "main"),
],
```

Apply the plugin to the targets to check, or to all of them at the end of the manifest:

```swift
.target(
    name: "Affairs SQLite",
    plugins: [.plugin(name: "Linter Build Errors Plugin", package: "swift-linter-rules")]
)
```

```swift
for target in package.targets where [.regular, .executable, .test].contains(target.type) {
    target.plugins =
        (target.plugins ?? []) + [.plugin(name: "Linter Build Errors Plugin", package: "swift-linter-rules")]
}
```

`swift build`, `xcodebuild` and Xcode's own build then run the check first. A finding stops the build before the
compiler starts.

### An Xcode project

Add the package to the project (File, Add Package Dependencies), then for each target: Build Phases, +, Run Build Tool
Plug-ins, Linter Build Errors Plugin. A target that belongs to a package in the workspace takes the plugin from that
package's manifest instead, as above.

### Approval

Xcode asks once to trust a package plugin, and `xcodebuild` refuses it without `-skipPackagePluginValidation`. Both
are approvals the owner of the project gives; a build script should not switch validation off.

### One run through `swift-linter`

To run just these rules from a `Lint.swift`, in CI or by hand, and nothing else:

```swift
// swift-linter-tools-version: 0.1

import Linter
import Linter_Rule_Build_Errors

Lint.run(dependencies: [
    .package(
        url: "https://github.com/swift-compositions/swift-linter-rules.git",
        branch: "main",
        products: ["Linter Rule Build Errors"]
    ),
]) {
    Lint.Rule.Bundle.buildErrors
}
```

`swift run swift-linter --exit-policy strict .` then exits non-zero on a finding.

### Checking that it fails

Plant an untyped multi-statement closure, such as `try database.read { db in if x { return a }; return b }`, in a
checked target. The build must fail with `error: [database closure type]` and the file and line, and pass once the
closure states its result type.

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
