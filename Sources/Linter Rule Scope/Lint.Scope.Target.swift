public import Lint

extension Lint.Scope {

    public enum Target {}
}

extension Lint.Scope.Target {

    public static func name(of path: Lint.Source.Path) -> Swift::String? {
        let components = path.underlying.split(separator: "/", omittingEmptySubsequences: true)
        let directories = components.dropLast()
        guard let anchor = directories.firstIndex(where: { $0 == "Sources" || $0 == "Tests" }) else {
            return nil
        }
        let target = directories.index(after: anchor)
        guard target < directories.endIndex else { return nil }
        return Swift::String(directories[target])
    }

    public static func named(
        _ path: Lint.Source.Path,
        suffix: Swift::String
    ) -> Swift::Bool {
        guard let name = name(of: path) else { return false }
        return name.count > suffix.count && name.hasSuffix(suffix)
    }

    /// Whether `path` is in a test target: its first directory is `Tests`.
    public static func isTest(_ path: Lint.Source.Path) -> Swift::Bool {
        path.underlying.split(separator: "/", omittingEmptySubsequences: true).dropLast().first == "Tests"
    }
}
