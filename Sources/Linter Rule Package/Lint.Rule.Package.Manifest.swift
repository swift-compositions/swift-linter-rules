package import Lint
package import SwiftSyntax

extension Lint.Rule.Package {
    /// What a manifest says about which dependencies its products load: the targets its products name, each
    /// target's dependencies with the traits that gate them, its own traits, and the traits it asks of each
    /// package it depends on.
    package struct Manifest {
        /// The targets the manifest's products name.
        package var products: Swift::Set<Swift::String>
        /// Every non-test target's dependencies.
        package var targets: [Swift::String: [Edge]]
        /// The traits `.default(enabledTraits:)` turns on.
        package var defaults: Swift::Set<Swift::String>
        /// The traits each trait turns on with it.
        package var implications: [Swift::String: Swift::Set<Swift::String>]
        /// The traits asked of each dependency, by identity.
        package var requests: [Swift::String: Request]
        /// Whether a `Package(...)` declaration with targets was read; without one, nothing is known.
        package var understood: Swift::Bool

        package init() {
            self.products = []
            self.targets = [:]
            self.defaults = []
            self.implications = [:]
            self.requests = [:]
            self.understood = false
        }
    }
}

extension Lint.Rule.Package.Manifest {

    package init(_ tree: SourceFileSyntax) {
        let visitor = Lint.Rule.Package.Manifest.Reader()
        visitor.walk(tree)
        self = visitor.manifest
    }

    /// The traits on in this package when the graph asks `requests` of it, with every implied trait.
    package func enabled(_ requests: [Request]) -> Swift::Set<Swift::String> {
        var pending = Swift::Array(requests.reduce(into: Swift::Set<Swift::String>()) { $0.formUnion($1.traits) })
        if requests.isEmpty || requests.contains(where: \.defaults) { pending.append(contentsOf: defaults) }
        var enabled: Swift::Set<Swift::String> = []
        while let trait = pending.popLast() {
            guard enabled.insert(trait).inserted else { continue }
            pending.append(contentsOf: implications[trait] ?? [])
        }
        return enabled
    }

    /// Whether a target that one of the products reaches uses `identity`, with `enabled` traits on; nil when the
    /// manifest was not understood.
    package func loads(_ identity: Swift::String, enabled: Swift::Set<Swift::String>) -> Swift::Bool? {
        guard understood else { return nil }
        func active(_ traits: Swift::Set<Swift::String>?) -> Swift::Bool {
            traits.map { !$0.isDisjoint(with: enabled) } ?? true
        }
        var pending = Swift::Array(products)
        var reached: Swift::Set<Swift::String> = []
        while let target = pending.popLast() {
            guard reached.insert(target).inserted else { continue }
            for edge in targets[target] ?? [] {
                switch edge {
                case .target(let name, let traits) where active(traits):
                    pending.append(name)
                case .product(let package, let traits) where active(traits) && package.lowercased() == identity:
                    return true
                default:
                    continue
                }
            }
        }
        return false
    }
}
