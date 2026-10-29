internal import Byte
internal import File_System
public import Lint

extension Lint.Source {

    public struct Fixture: ~Copyable {

        public let root: Swift::String

        public let files: [Swift::String: Swift::String]

        public init(files: [Swift::String: Swift::String]) throws(Failure) {
            self.root = try Self.temporaryRoot(prefix: "linter-rules-fixture-")
            self.files = files
            for (relative, content) in files {
                try Self.write(content, to: root + "/" + relative)
            }
        }

        deinit {
            Self.remove(root)
        }
    }
}

extension Lint.Source.Fixture {

    public struct Failure: Swift::Error {
        public let reason: Swift::String

        public init(reason: Swift::String) {
            self.reason = reason
        }
    }

    public func parsed(_ relative: Swift::String) -> Lint.Source.Parsed {
        Lint.Source.parsed(
            from: files[relative] ?? "",
            file: root + "/" + relative,
            path: Lint.Source.Path(relative)
        )
    }
}

extension Lint.Source.Fixture {

    /// A fresh path in the platform's temporary directory, written with `/` separators.
    public static func temporaryRoot(prefix: Swift::String) throws(Failure) -> Swift::String {
        var random = Swift::SystemRandomNumberGenerator()
        do {
            let path = try File.Path.Temporary.deterministic(prefix: prefix, key: "\(random.next())", suffix: "")
            return Swift::String(path.string.map { $0 == "\\" ? "/" : $0 })
        } catch {
            throw Failure(reason: "no temporary directory: \(error)")
        }
    }

    /// Writes `content` to `raw`, creating the directories above it.
    public static func write(_ content: Swift::String, to raw: Swift::String) throws(Failure) {
        let path: File.Path
        do {
            path = try File.Path(raw)
        } catch {
            throw Failure(reason: "invalid path: \(raw)")
        }
        let bytes = [Byte](utf8: content)
        do {
            try File.System.Write.Atomic.write(bytes.span, to: path, createIntermediates: true)
        } catch {
            throw Failure(reason: "write failed: \(raw): \(error)")
        }
    }

    /// Removes `raw` and everything under it; a path that is already gone is not an error.
    public static func remove(_ raw: Swift::String) {
        guard let path = try? File.Path(raw) else { return }
        _ = try? File.System.Delete.delete(at: path, recursive: true)
    }
}
