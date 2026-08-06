// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import File_System
internal import SwiftParser
internal import SwiftSyntax

/// F9 predicate parity (2026-08-06) — `[TARGET-IMPORT-EDGE]`: every
/// module a target's sources `import` (any form) MUST appear in that
/// target's `dependencies:` in `Package.swift`, as a same-package
/// target dependency or a cross-package product dependency. Excepted:
/// the target's own module and toolchain/SDK-supplied modules. An
/// import satisfied only transitively is an undeclared build edge —
/// whether the target compiles becomes a build-plan scheduling race.
///
/// Mirrors the incumbent Python surface
/// `swift-institute/.github/.github/scripts/validate-target-imports.py`:
///
/// - The rule evaluates when the linted file is a `Package.swift`; the
///   package root is the manifest's on-disk directory. Findings anchor
///   at the offending target's `name:` in the manifest and name the
///   importing source `file:line` in the message (the single-file rule
///   shape has no other location to attach cross-file findings to —
///   deliberate deviation from the Python's per-source TSV rows).
/// - Manifest facts come from a SwiftSyntax parse of the manifest
///   (targets, per-target `target`/`product`/`byName` dependencies,
///   `.package(url:)`/`.package(path:)` declarations, `.library`
///   products) rather than `swift package dump-package` — a lint rule
///   spawns no subprocess. Deviation: computed manifest values the
///   declarative parse cannot see are not resolved; such targets
///   simply contribute no findings (under-report, never false-fire).
/// - Allowed set per target = own module ∪ same-package target deps
///   (normalized names) ∪ declared product deps' member modules (dep
///   manifests resolved locally: path deps on disk, url deps via the
///   `<root>/../../<org>/<name>` checkout layout — same resolution as
///   the Python) ∪ the toolchain set below. `byName` deps resolve to a
///   same-package target first, else to a like-named product of any
///   declared dep.
/// - Unresolvable dep manifests degrade soft: their products' member
///   modules are unknown, so the whole run under-reports (no findings)
///   rather than false-firing — identical to the Python's soft mode.
/// - Imports are read from a SwiftParser parse of each target source
///   file (first dotted component of every `import` declaration, all
///   scoped/attributed forms). Deviation: parser-accurate versus the
///   Python's line regex; comments and strings never match.
///
/// Citation: swift-institute/.github#358 transaction F9.
extension Lint.Rule {
    /// Flags a target whose sources import a module without a declared manifest dependency edge (mirror of validate-target-imports.py, [TARGET-IMPORT-EDGE]).
    public static let `target import edge` = Lint.Rule(
        id: "target import edge",
        // ADVISORY at introduction per the standing graduation
        // discipline — promote to `.error` only after fleet validation.
        default: .warning,
        findings: { source, severity in
            packageTargetImportEdgeFindings(source: source, severity: severity)
        }
    )
}

// MARK: - Toolchain carve

/// Toolchain/SDK-supplied modules (the rule's carve) — identical to the
/// Python's `TOOLCHAIN_MODULES`.
internal let packageTargetImportEdgeToolchainModules: Swift.Set<Swift.String> = [
    "Swift", "Testing", "XCTest", "Foundation", "FoundationEssentials",
    "Dispatch", "os", "Darwin", "Glibc", "Musl", "WinSDK", "Android",
    "Observation", "Synchronization", "Builtin", "CRT", "ucrt",
    "SwiftShims", "DistributedActors", "Distributed", "RegexBuilder",
    "StringProcessing", "CoreFoundation", "ObjectiveC", "simd", "Accelerate",
]

/// Directory names never descended into — identical to the Python's
/// `SKIP_DIRS`.
internal let packageTargetImportEdgeSkipDirectories: Swift.Set<Swift.String> = [
    ".build", ".git", ".swiftpm", ".claude", "node_modules", "checkouts",
]

/// Mirror of the Python's `normalize`: module names use `_` where the
/// target/product name uses spaces or hyphens.
internal func packageTargetImportEdgeNormalize(_ name: Swift.String) -> Swift.String {
    var out = ""
    out.reserveCapacity(name.count)
    for character in name {
        out.append(character == " " || character == "-" ? "_" : character)
    }
    return out
}

// MARK: - Manifest model

/// One target declaration read from a manifest parse.
internal struct PackageTargetImportEdgeTarget {
    internal enum Kind {
        case target
        case executableTarget
        case testTarget
        case macro
    }

    internal enum Dependency {
        /// `.target(name: "X")`
        case target(Swift.String)
        /// `.product(name: "X", package: ...)`
        case product(Swift.String)
        /// `"X"` or `.byName(name: "X")`
        case byName(Swift.String)
    }

    internal var name: Swift.String = ""
    internal var kind: Kind = .target
    internal var explicitPath: Swift.String?
    internal var dependencies: [Dependency] = []
    internal var namePosition: AbsolutePosition = AbsolutePosition(utf8Offset: 0)
}

/// Everything the rule needs from one manifest parse.
internal struct PackageTargetImportEdgeManifest {
    internal var targets: [PackageTargetImportEdgeTarget] = []
    /// `.library(name:targets:)` products — product name → member target names.
    internal var products: [Swift.String: Swift.Set<Swift.String>] = [:]
    /// `.package(url: "...")` declarations.
    internal var urlDependencies: [Swift.String] = []
    /// `.package(path: "...")` declarations.
    internal var pathDependencies: [Swift.String] = []
}

// MARK: - Manifest visitor

internal final class PackageTargetImportEdgeManifestVisitor: SyntaxVisitor {
    internal var manifest = PackageTargetImportEdgeManifest()

    internal init() {
        super.init(viewMode: .sourceAccurate)
    }

    private func stringLiteralValue(_ expression: ExprSyntax) -> Swift.String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else { return nil }
        var out = ""
        for segment in literal.segments {
            guard let text = segment.as(StringSegmentSyntax.self) else { return nil }
            out += text.content.text
        }
        return out
    }

    private func argument(_ node: FunctionCallExprSyntax, labeled label: Swift.String) -> ExprSyntax? {
        for argument in node.arguments where argument.label?.text == label {
            return argument.expression
        }
        return nil
    }

    private func dependency(from expression: ExprSyntax) -> PackageTargetImportEdgeTarget.Dependency? {
        if let name = stringLiteralValue(expression) {
            return .byName(name)
        }
        guard let call = expression.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self),
            let nameExpression = argument(call, labeled: "name"),
            let name = stringLiteralValue(nameExpression)
        else { return nil }
        switch member.declName.baseName.text {
        case "target": return .target(name)
        case "product": return .product(name)
        case "byName": return .byName(name)
        default: return nil
        }
    }

    override internal func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        switch member.declName.baseName.text {
        case "package":
            if let expression = argument(node, labeled: "url"),
                let url = stringLiteralValue(expression)
            {
                manifest.urlDependencies.append(url)
            } else if let expression = argument(node, labeled: "path"),
                let path = stringLiteralValue(expression)
            {
                manifest.pathDependencies.append(path)
            }

        case "library":
            if let nameExpression = argument(node, labeled: "name"),
                let name = stringLiteralValue(nameExpression),
                let targetsExpression = argument(node, labeled: "targets"),
                let array = targetsExpression.as(ArrayExprSyntax.self)
            {
                var members: Swift.Set<Swift.String> = []
                for element in array.elements {
                    if let target = stringLiteralValue(element.expression) {
                        members.insert(packageTargetImportEdgeNormalize(target))
                    }
                }
                manifest.products[name] = members
            }

        case "target", "executableTarget", "testTarget", "macro":
            guard let nameExpression = argument(node, labeled: "name"),
                let name = stringLiteralValue(nameExpression)
            else { break }
            var target = PackageTargetImportEdgeTarget()
            target.name = name
            target.namePosition = nameExpression.positionAfterSkippingLeadingTrivia
            switch member.declName.baseName.text {
            case "executableTarget": target.kind = .executableTarget
            case "testTarget": target.kind = .testTarget
            case "macro": target.kind = .macro
            default: target.kind = .target
            }
            if let pathExpression = argument(node, labeled: "path"),
                let path = stringLiteralValue(pathExpression)
            {
                target.explicitPath = path
            }
            if let dependenciesExpression = argument(node, labeled: "dependencies"),
                let array = dependenciesExpression.as(ArrayExprSyntax.self)
            {
                for element in array.elements {
                    if let dependency = dependency(from: element.expression) {
                        target.dependencies.append(dependency)
                    }
                }
            }
            manifest.targets.append(target)

        default:
            break
        }
        return .visitChildren
    }
}

// MARK: - Import visitor

internal final class PackageTargetImportEdgeImportVisitor: SyntaxVisitor {
    /// module → line of first sighting in this file.
    internal var imports: [Swift.String: Swift.Int] = [:]
    private let converter: SourceLocationConverter

    internal init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override internal func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let first = node.path.first else { return .skipChildren }
        let module = first.name.text
        if imports[module] == nil {
            imports[module] = converter.location(
                for: node.positionAfterSkippingLeadingTrivia
            ).line
        }
        return .skipChildren
    }
}

// MARK: - Filesystem access (read-only)

/// Reads a UTF-8 text file, or `nil` on any failure. The rule degrades
/// soft on I/O failure (under-report, never false-fire), mirroring the
/// Python's `errors="replace"` / `OSError` handling.
internal func packageTargetImportEdgeReadText(atPath raw: Swift.String) -> Swift.String? {
    guard let path = try? File.Path(raw) else { return nil }
    return try? File(path).read.full { (span: Swift.Span<Byte>) -> Swift.String in
        var bytes: [Swift.UInt8] = []
        bytes.reserveCapacity(span.count)
        for index in span.indices {
            bytes.append(span[index].underlying)
        }
        return Swift.String(decoding: bytes, as: Swift.UTF8.self)
    }
}

internal func packageTargetImportEdgeIsDirectory(_ raw: Swift.String) -> Swift.Bool {
    guard let path = try? File.Path(raw) else { return false }
    return (try? File.Directory(path).entries()) != nil
}

internal func packageTargetImportEdgeIsFile(_ raw: Swift.String) -> Swift.Bool {
    guard let path = try? File.Path(raw) else { return false }
    return (try? File(path).read.full { (_: Swift.Span<Byte>) -> Swift.Bool in true }) ?? false
}

/// Recursively collects `*.swift` file paths under `directory`,
/// skipping ``packageTargetImportEdgeSkipDirectories`` — mirror of the
/// Python's pruned `os.walk`.
internal func packageTargetImportEdgeSwiftFiles(under directory: Swift.String) -> [Swift.String] {
    guard let path = try? File.Path(directory) else { return [] }
    guard let entries = try? File.Directory(path).entries() else { return [] }
    var out: [Swift.String] = []
    for entry in entries {
        let name = Swift.String(lossy: entry.name)
        let child = directory + "/" + name
        switch entry.type {
        case .directory:
            guard !packageTargetImportEdgeSkipDirectories.contains(name) else { continue }
            out.append(contentsOf: packageTargetImportEdgeSwiftFiles(under: child))

        case .file:
            if name.hasSuffix(".swift") {
                out.append(child)
            }

        case .symbolicLink, .other:
            continue
        }
    }
    return out.sorted()
}

// MARK: - Findings

internal func packageTargetImportEdgeFindings(
    source: borrowing Lint.Source.Parsed,
    severity: Diagnostic.Severity
) -> [Diagnostic.Record] {
    // Gate: the rule evaluates on `Package.swift` parses only.
    let runPath = Swift.String(describing: source.path)
    guard runPath == "Package.swift" || runPath.hasSuffix("/Package.swift") else { return [] }

    // Package root: the manifest's on-disk directory. Without a
    // resolvable root the cross-file predicate cannot be evaluated;
    // degrade soft.
    let filePath = source.file.filePath
    guard filePath.hasSuffix("/Package.swift") else { return [] }
    let root = Swift.String(filePath.dropLast("/Package.swift".count))
    guard packageTargetImportEdgeIsDirectory(root) else { return [] }

    let visitor = PackageTargetImportEdgeManifestVisitor()
    visitor.walk(source.tree)
    let manifest = visitor.manifest

    // Resolve dependency manifests locally — path deps on disk, url
    // deps via the `<root>/../../<org>/<name>` checkout layout (mirror
    // of the Python's `local_dep_manifests`).
    var dependencyManifestPaths: [Swift.String] = []
    var resolvedCount = 0
    for relative in manifest.pathDependencies {
        let candidate = root + "/" + relative + "/Package.swift"
        if packageTargetImportEdgeIsFile(candidate) {
            dependencyManifestPaths.append(candidate)
            resolvedCount += 1
        }
    }
    for url in manifest.urlDependencies {
        var trimmed = url
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let parts = trimmed.split(separator: "/").map(Swift.String.init)
        guard parts.count >= 2 else { continue }
        var name = parts[parts.count - 1]
        if name.hasSuffix(".git") { name = Swift.String(name.dropLast(4)) }
        let organization = parts[parts.count - 2]
        let candidate = root + "/../../" + organization + "/" + name + "/Package.swift"
        if packageTargetImportEdgeIsFile(candidate) {
            dependencyManifestPaths.append(candidate)
            resolvedCount += 1
        }
    }
    let declaredCount = manifest.pathDependencies.count + manifest.urlDependencies.count
    // Deps not resolvable locally → soft mode (under-report), identical
    // to the Python's `unresolvable_deps` flag.
    let unresolvableDependencies = declaredCount > resolvedCount

    // Product name → member module names, across every resolved dep.
    var dependencyProducts: [Swift.String: Swift.Set<Swift.String>] = [:]
    for manifestPath in dependencyManifestPaths {
        guard let text = packageTargetImportEdgeReadText(atPath: manifestPath) else { continue }
        let tree = Parser.parse(source: text)
        let dependencyVisitor = PackageTargetImportEdgeManifestVisitor()
        dependencyVisitor.walk(tree)
        for (product, members) in dependencyVisitor.manifest.products {
            dependencyProducts[product, default: []].formUnion(members)
        }
    }

    let samePackageTargets = Swift.Set(manifest.targets.map(\.name))
    var records: [Diagnostic.Record] = []

    for target in manifest.targets {
        let sourceDirectory: Swift.String
        if let explicit = target.explicitPath {
            sourceDirectory = root + "/" + explicit
        } else {
            let base = target.kind == .testTarget ? "Tests" : "Sources"
            sourceDirectory = root + "/" + base + "/" + target.name
        }
        guard packageTargetImportEdgeIsDirectory(sourceDirectory) else { continue }

        var allowed: Swift.Set<Swift.String> = [packageTargetImportEdgeNormalize(target.name)]
        for dependency in target.dependencies {
            switch dependency {
            case .target(let name):
                allowed.insert(packageTargetImportEdgeNormalize(name))

            case .product(let name):
                if let members = dependencyProducts[name] {
                    allowed.formUnion(members)
                } else {
                    // Unresolved product: soft — accept its own name.
                    allowed.insert(packageTargetImportEdgeNormalize(name))
                }

            case .byName(let name):
                if samePackageTargets.contains(name) {
                    allowed.insert(packageTargetImportEdgeNormalize(name))
                } else {
                    if let members = dependencyProducts[name] {
                        allowed.formUnion(members)
                    }
                    allowed.insert(packageTargetImportEdgeNormalize(name))
                }
            }
        }

        // module → (relative file, line) — first sighting wins, mirror
        // of the Python's `imports_of`.
        var sightings: [Swift.String: (Swift.String, Swift.Int)] = [:]
        for swiftFile in packageTargetImportEdgeSwiftFiles(under: sourceDirectory) {
            guard let text = packageTargetImportEdgeReadText(atPath: swiftFile) else { continue }
            let tree = Parser.parse(source: text)
            let converter = SourceLocationConverter(fileName: swiftFile, tree: tree)
            let importVisitor = PackageTargetImportEdgeImportVisitor(converter: converter)
            importVisitor.walk(tree)
            var relative = swiftFile
            if relative.hasPrefix(root + "/") {
                relative = Swift.String(relative.dropFirst(root.count + 1))
            }
            for (module, line) in importVisitor.imports where sightings[module] == nil {
                sightings[module] = (relative, line)
            }
        }

        for module in sightings.keys.sorted() {
            guard let (relative, line) = sightings[module] else { continue }
            if packageTargetImportEdgeToolchainModules.contains(module) { continue }
            if module.hasPrefix("_") { continue }
            if allowed.contains(module) { continue }
            if unresolvableDependencies { continue }  // soft mode
            let location = source.converter.location(for: target.namePosition)
            records.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "target import edge",
                    message: "[target import edge]: \(relative):\(line): target "
                        + "'\(target.name)' imports '\(module)' without a declared "
                        + "dependency edge ([TARGET-IMPORT-EDGE]: transitive-build "
                        + "riding is a scheduling race; declare the target/product "
                        + "dependency)"
                )
            )
        }
    }
    return records
}
