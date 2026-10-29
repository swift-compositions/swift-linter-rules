public import Lint
internal import Linter_Rule_Scope
internal import SwiftParser
internal import SwiftSyntax

extension Lint.Rule {

    /// One package identity spelled with two locations in a root package's resolved closure.
    ///
    /// Reads the `Package.resolved` beside a root `Package.swift`, and the manifests SwiftPM checked
    /// out for its pins under `.build/checkouts`. Every `.package(url:)` in the root and in those
    /// checkouts whose identity is pinned must canonicalise to the pin's location. Unpinned
    /// identities are never loaded, so they are not checked. The rule sees only what is on disk: a
    /// package without `Package.resolved` or checkouts contributes nothing, and an Xcode workspace's
    /// own resolution (`xcshareddata/swiftpm`, DerivedData checkouts) is not read.
    public static let `conflicting dependency url` = Lint.Rule(
        id: "conflicting dependency url",

        default: .warning,
        controls: [
            .init(
                id: "conflicting dependency url absent resolution",
                source: """
                    import PackageDescription

                    let package = Package(
                        name: "Fixture",
                        dependencies: [
                            .package(url: "https://github.com/swift-molecules/swift-interface.git", branch: "main")
                        ]
                    )
                    """,
                path: "/Controls/ConflictingDependencyURL/Package.swift",
                expectation: .clean
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            packageConflictingDependencyURLFindings(source: source, severity: severity)
        }
    )
}

/// The location SwiftPM compares to decide whether two spellings name one package: lowercased,
/// without scheme, user, `.git` or trailing `/`, and with an scp-style `host:path` read as
/// `host/path`.
package func packageConflictingDependencyURLCanonical(_ url: Swift::String) -> Swift::String {
    var location = url.lowercased()
    while location.hasSuffix("/") { location.removeLast() }
    if location.hasSuffix(".git") { location.removeLast(4) }
    while location.hasSuffix("/") { location.removeLast() }
    if let scheme = location.firstRange(of: "://") {
        location = Swift::String(location[scheme.upperBound...])
    }
    let host = location.prefix(while: { $0 != "/" })
    if let at = host.lastIndex(of: "@") {
        location = Swift::String(location[location.index(after: at)...])
    }
    if let colon = location.prefix(while: { $0 != "/" }).firstIndex(of: ":") {
        location.replaceSubrange(colon...colon, with: "/")
    }
    return location
}

/// SwiftPM's identity for a location: its last path component, canonicalised.
package func packageConflictingDependencyURLIdentity(_ url: Swift::String) -> Swift::String {
    let canonical = packageConflictingDependencyURLCanonical(url)
    return canonical.split(separator: "/").last.map(Swift::String.init) ?? canonical
}

/// The pins of a `Package.resolved`, identity to location. Reads version 2 and 3 pins
/// (`identity`, `location`) and version 1 pins (`repositoryURL`).
package func packageConflictingDependencyURLPins(
    _ text: Swift::String
) -> [Swift::String: Swift::String] {
    let characters = Swift::Array(text)
    var strings: [(value: Swift::String, isKey: Swift::Bool)] = []
    var index = 0
    while index < characters.count {
        guard characters[index] == "\"" else {
            index += 1
            continue
        }
        index += 1
        var value = ""
        while index < characters.count, characters[index] != "\"" {
            if characters[index] == "\\", index + 1 < characters.count { index += 1 }
            value.append(characters[index])
            index += 1
        }
        index += 1
        var next = index
        while next < characters.count, characters[next].isWhitespace { next += 1 }
        strings.append((value, next < characters.count && characters[next] == ":"))
    }

    var pins: [Swift::String: Swift::String] = [:]
    var identity: Swift::String?
    var position = 0
    while position + 1 < strings.count {
        let key = strings[position]
        let value = strings[position + 1]
        guard key.isKey, !value.isKey else {
            position += 1
            continue
        }
        switch key.value {
        case "identity":
            identity = value.value
        case "location":
            if let pinned = identity { pins[pinned] = value.value }
            identity = nil
        case "repositoryURL":
            pins[packageConflictingDependencyURLIdentity(value.value)] = value.value
        default:
            break
        }
        position += 2
    }
    return pins
}

package func packageConflictingDependencyURLFindings(
    source: borrowing Lint.Source.Parsed,
    severity: Diagnostic.Severity
) -> [Diagnostic.Record] {

    let runPath = Swift::String(describing: source.path)
    guard runPath == "Package.swift" || runPath.hasSuffix("/Package.swift") else { return [] }

    let filePath = source.file.filePath
    guard filePath.hasSuffix("/Package.swift") else { return [] }
    let root = Swift::String(filePath.dropLast("/Package.swift".count))
    guard let resolved = Lint.Scope.File.text(at: root + "/Package.resolved") else { return [] }
    let pins = packageConflictingDependencyURLPins(resolved)
    guard !pins.isEmpty else { return [] }

    let rootVisitor = PackageConflictingDependencyURLVisitor()
    rootVisitor.walk(source.tree)

    typealias Spelling = (url: Swift::String, line: Swift::Int)
    let rootSpellings: [Spelling] = rootVisitor.urls.map { dependency in
        (dependency.url, source.converter.location(for: dependency.position).line)
    }
    var manifests: [(relative: Swift::String, urls: [Spelling])] = [("Package.swift", rootSpellings)]

    let checkouts = root + "/.build/checkouts"
    var directories: [Swift::String: Swift::String] = [:]
    for name in Lint.Scope.File.entries(in: checkouts) {
        directories[name.lowercased()] = name
    }
    for identity in pins.keys.sorted() {
        guard let location = pins[identity] else { continue }
        let candidates = [packageConflictingDependencyURLIdentity(location), identity]
        guard let directory = candidates.lazy.compactMap({ directories[$0] }).first else { continue }
        let relative = ".build/checkouts/" + directory + "/Package.swift"
        guard let text = Lint.Scope.File.text(at: root + "/" + relative) else { continue }
        let tree = Parser.parse(source: text)
        let converter = SourceLocationConverter(fileName: relative, tree: tree)
        let visitor = PackageConflictingDependencyURLVisitor()
        visitor.walk(tree)
        let spellings: [Spelling] = visitor.urls.map { dependency in
            (dependency.url, converter.location(for: dependency.position).line)
        }
        manifests.append((relative, spellings))
    }

    var rootPositions: [Swift::String: AbsolutePosition] = [:]
    for (url, position) in rootVisitor.urls {
        let identity = packageConflictingDependencyURLIdentity(url)
        if rootPositions[identity] == nil { rootPositions[identity] = position }
    }

    var records: [Diagnostic.Record] = []
    for (index, manifest) in manifests.enumerated() {
        for (offset, dependency) in manifest.urls.enumerated() {
            let identity = packageConflictingDependencyURLIdentity(dependency.url)
            guard let pinned = pins[identity],
                packageConflictingDependencyURLCanonical(dependency.url)
                    != packageConflictingDependencyURLCanonical(pinned)
            else { continue }
            let position: AbsolutePosition
            let spelledBy: Swift::String
            if index == 0 {
                position = rootVisitor.urls[offset].position
                spelledBy = "this manifest spells it"
            } else {
                position = rootPositions[identity] ?? source.tree.positionAfterSkippingLeadingTrivia
                spelledBy = "`\(manifest.relative):\(dependency.line)` spells it"
            }
            let location = source.converter.location(for: position)
            records.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "conflicting dependency url",
                    message: "[conflicting dependency url]: `\(identity)` is pinned at `\(pinned)`, but "
                        + "\(spelledBy) `\(dependency.url)`. Two spellings of one package in a graph make "
                        + "SwiftPM walk every dependency path to reconcile them; spell it one way in "
                        + "every manifest of the graph, or move the pin of the package that spells it "
                        + "differently."
                )
            )
        }
    }
    return records
}
