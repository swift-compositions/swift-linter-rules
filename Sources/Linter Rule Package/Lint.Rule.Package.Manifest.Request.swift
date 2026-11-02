internal import Lint

extension Lint.Rule.Package.Manifest {

    /// The traits one `.package(url:)` asks for: its listed traits, and whether it takes the package's defaults
    /// (no `traits:` argument, or `.defaults` among them).
    package struct Request {
        package var traits: Swift::Set<Swift::String>
        package var defaults: Swift::Bool

        package init(traits: Swift::Set<Swift::String> = [], defaults: Swift::Bool = false) {
            self.traits = traits
            self.defaults = defaults
        }
    }
}
