internal import Byte
internal import File_System
public import Lint

private typealias FilePath = File.Path

extension Lint.Scope {

    public enum File {}
}

extension Lint.Scope.File {

    public static let skipped: Swift::Set<Swift::String> = [
        ".build", ".git", ".swiftpm", ".claude", "node_modules", "checkouts", "DerivedData",
    ]

    public static func swiftFiles(under directory: Swift::String) -> [Swift::String] {
        var out: [Swift::String] = []
        for name in entries(in: directory) {
            let child = directory + "/" + name
            if isDirectory(child) {
                guard !skipped.contains(name), !name.hasSuffix(".docc") else { continue }
                out.append(contentsOf: swiftFiles(under: child))
            } else if isFile(child), name.hasSuffix(".swift") {
                out.append(child)
            }
        }
        return out.sorted()
    }
}

extension Lint.Scope.File {

    public static func text(at raw: Swift::String) -> Swift::String? {
        guard let path = try? FilePath(raw) else { return nil }
        return try? File.System.Read.Full.read(from: path) { span -> Swift::String in
            var bytes: [Swift::UInt8] = []
            bytes.reserveCapacity(span.count)
            for index in span.indices {
                bytes.append(span[index].bitPattern)
            }
            return Swift::String(decoding: bytes, as: Swift::UTF8.self)
        }
    }

    public static func isDirectory(_ raw: Swift::String) -> Swift::Bool {
        guard let path = try? FilePath(raw), let info = try? File.System.Stat.info(at: path) else { return false }
        if case .directory = info.type { return true }
        return false
    }

    public static func isFile(_ raw: Swift::String) -> Swift::Bool {
        guard let path = try? FilePath(raw), let info = try? File.System.Stat.info(at: path) else { return false }
        if case .regular = info.type { return true }
        return false
    }

    public static func entries(in directory: Swift::String) -> [Swift::String] {
        guard let path = try? FilePath(directory),
            let listing = try? File.Directory.Contents.list(at: File.Directory(path))
        else { return [] }
        return listing.compactMap { Swift::String($0.name) }.sorted()
    }
}

extension Lint.Scope.File {

    /// Whether `path`'s last component is a package manifest: exactly `Package.swift`, or `Package@swift-<version>.swift`
    /// with a non-empty version. `MyPackage.swift` is not.
    public static func isManifest(_ path: Lint.Source.Path) -> Swift::Bool {
        guard let name = path.underlying.split(separator: "/", omittingEmptySubsequences: true).last else { return false }
        if name == "Package.swift" { return true }
        let prefix = "Package@swift-"
        let suffix = ".swift"
        return name.hasPrefix(prefix) && name.hasSuffix(suffix) && name.count > prefix.count + suffix.count
    }

    public static func root(of source: borrowing Lint.Source.Parsed) -> Swift::String? {
        let relative = source.path.underlying
        let absolute = Swift::String(source.file.filePath.map { $0 == "\\" ? "/" : $0 })
        guard !relative.isEmpty, isAbsolute(absolute), absolute.hasSuffix("/" + relative) else {
            return nil
        }
        let root = Swift::String(absolute.dropLast(relative.count + 1))
        guard !root.isEmpty, isDirectory(root) else { return nil }
        return root
    }
}

extension Lint.Scope.File {

    /// Whether `path`, written with `/` separators, is rooted: a leading `/`, or a drive letter and `:/`.
    private static func isAbsolute(_ path: Swift::String) -> Swift::Bool {
        if path.hasPrefix("/") { return true }
        let scalars = Swift::Array(path.unicodeScalars.prefix(3))
        return scalars.count == 3 && scalars[0].properties.isAlphabetic && scalars[1] == ":" && scalars[2] == "/"
    }
}
