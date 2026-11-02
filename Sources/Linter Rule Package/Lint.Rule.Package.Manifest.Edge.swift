internal import Lint

extension Lint.Rule.Package.Manifest {

    /// A target's dependency, with the traits of its `condition: .when(traits:)`, or nil when no trait gates it.
    package enum Edge {
        case target(Swift::String, traits: Swift::Set<Swift::String>?)
        case product(package: Swift::String, traits: Swift::Set<Swift::String>?)
    }
}
