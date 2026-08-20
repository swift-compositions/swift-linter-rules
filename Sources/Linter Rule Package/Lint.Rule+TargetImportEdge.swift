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
internal import SwiftParser
internal import SwiftSyntax

#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#elseif canImport(Musl)
    internal import Musl
#elseif canImport(Android)
    internal import Android
#endif

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
package let packageTargetImportEdgeToolchainModules: Swift.Set<Swift.String> = [
    "Swift", "Testing", "XCTest", "Foundation", "FoundationEssentials",
    "Dispatch", "os", "Darwin", "Glibc", "Musl", "WinSDK", "Android",
    "Observation", "Synchronization", "Builtin", "CRT", "ucrt",
    "SwiftShims", "DistributedActors", "Distributed", "RegexBuilder",
    "StringProcessing", "CoreFoundation", "ObjectiveC", "simd", "Accelerate",
]

/// Directory names never descended into — identical to the Python's
/// `SKIP_DIRS`.
package let packageTargetImportEdgeSkipDirectories: Swift.Set<Swift.String> = [
    ".build", ".git", ".swiftpm", ".claude", "node_modules", "checkouts",
]

/// Mirror of the Python's `normalize`: module names use `_` where the
/// target/product name uses spaces or hyphens.
package func packageTargetImportEdgeNormalize(_ name: Swift.String) -> Swift.String {
    var out = ""
    out.reserveCapacity(name.count)
    for character in name {
        out.append(character == " " || character == "-" ? "_" : character)
    }
    return out
}

// MARK: - Filesystem access (read-only)
//
// The cross-file predicate this rule mirrors is inherently
// filesystem-shaped: the Python walks target source directories and
// reads dependency manifests from disk. The access here is contained,
// read-only, and POSIX-direct (no filesystem package dependency — the
// rule pack's graph stays SwiftSyntax + Linter Primitives). On
// platforms without a POSIX surface the helpers return empty, and the
// rule under-reports (soft), never false-fires.

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android)

    /// Reads a UTF-8 text file, or `nil` on any failure.
    ///
    /// The rule degrades soft on I/O failure (under-report, never
    /// false-fire), mirroring the Python's `errors="replace"` /
    /// `OSError` handling.
    package func packageTargetImportEdgeReadText(atPath raw: Swift.String) -> Swift.String? {
        guard let handle = unsafe fopen(raw, "rb") else { return nil }
        defer { _ = unsafe fclose(handle) }
        var bytes: [Swift.UInt8] = []
        var buffer = [Swift.UInt8](repeating: 0, count: 4096)
        while true {
            let count = buffer.withUnsafeMutableBytes { pointer in
                unsafe fread(pointer.baseAddress, 1, pointer.count, handle)
            }
            guard count > 0 else { break }
            bytes.append(contentsOf: buffer[0..<count])
        }
        return Swift.String(decoding: bytes, as: Swift.UTF8.self)
    }

    package func packageTargetImportEdgeIsDirectory(_ raw: Swift.String) -> Swift.Bool {
        var status = stat()
        guard unsafe stat(raw, &status) == 0 else { return false }
        return (status.st_mode & S_IFMT) == S_IFDIR
    }

    package func packageTargetImportEdgeIsFile(_ raw: Swift.String) -> Swift.Bool {
        var status = stat()
        guard unsafe stat(raw, &status) == 0 else { return false }
        return (status.st_mode & S_IFMT) == S_IFREG
    }

    /// The entry names of a directory (sorted, `.`/`..` excluded), or
    /// empty on any failure.
    package func packageTargetImportEdgeEntryNames(in directory: Swift.String) -> [Swift.String] {
        guard let handle = unsafe opendir(directory) else { return [] }
        defer { _ = unsafe closedir(handle) }
        var names: [Swift.String] = []
        while let entry = unsafe readdir(handle) {
            let name = unsafe withUnsafeBytes(of: entry.pointee.d_name) { pointer in
                unsafe Swift.String(
                    decoding: pointer.prefix(while: { $0 != 0 }),
                    as: Swift.UTF8.self
                )
            }
            if name == "." || name == ".." { continue }
            names.append(name)
        }
        return names.sorted()
    }

#else

    package func packageTargetImportEdgeReadText(atPath raw: Swift.String) -> Swift.String? { nil }
    package func packageTargetImportEdgeIsDirectory(_ raw: Swift.String) -> Swift.Bool { false }
    package func packageTargetImportEdgeIsFile(_ raw: Swift.String) -> Swift.Bool { false }
    package func packageTargetImportEdgeEntryNames(in directory: Swift.String) -> [Swift.String] {
        []
    }

#endif

/// Recursively collects `*.swift` file paths under `directory`,
/// skipping ``packageTargetImportEdgeSkipDirectories`` — mirror of the
/// Python's pruned `os.walk`.
package func packageTargetImportEdgeSwiftFiles(under directory: Swift.String) -> [Swift.String] {
    var out: [Swift.String] = []
    for name in packageTargetImportEdgeEntryNames(in: directory) {
        let child = directory + "/" + name
        if packageTargetImportEdgeIsDirectory(child) {
            guard !packageTargetImportEdgeSkipDirectories.contains(name) else { continue }
            out.append(contentsOf: packageTargetImportEdgeSwiftFiles(under: child))
        } else if packageTargetImportEdgeIsFile(child), name.hasSuffix(".swift") {
            out.append(child)
        }
    }
    return out.sorted()
}

// MARK: - Findings

package func packageTargetImportEdgeFindings(
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
        let tail = parts.suffix(2)
        guard tail.count == 2, let organization = tail.first, var name = tail.last else { continue }
        if name.hasSuffix(".git") { name = Swift.String(name.dropLast(4)) }
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
