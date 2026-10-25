public import Lint

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Android)
  import Android
#endif

extension Lint.Source {

  public struct Fixture: ~Copyable {

    public let root: Swift::String

    public let files: [Swift::String: Swift::String]

    public init(files: [Swift::String: Swift::String]) throws(Failure) {
      var random = Swift::SystemRandomNumberGenerator()
      self.root = "/tmp/linter-rules-fixture-\(random.next())"
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
  }

  public func parsed(_ relative: Swift::String) -> Lint.Source.Parsed {
    Lint.Source.parsed(
      from: files[relative] ?? "",
      file: root + "/" + relative,
      path: Lint.Source.Path(relative)
    )
  }
}

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android)

  extension Lint.Source.Fixture {

    fileprivate static func makeDirectories(_ raw: Swift::String) throws(Failure) {
      var prefix = ""
      for component in raw.split(separator: "/") {
        prefix += "/" + component
        guard unsafe mkdir(prefix, 0o755) == 0 || errno == EEXIST else {
          throw Failure(reason: "mkdir failed: \(prefix)")
        }
      }
    }

    fileprivate static func write(_ content: Swift::String, to raw: Swift::String) throws(Failure) {
      if let slash = raw.lastIndex(of: "/") {
        try makeDirectories(Swift::String(raw[raw.startIndex..<slash]))
      }
      guard let handle = unsafe fopen(raw, "wb") else {
        throw Failure(reason: "fopen failed: \(raw)")
      }
      defer { _ = unsafe fclose(handle) }
      let bytes = [Swift::UInt8](content.utf8)
      let written = bytes.withUnsafeBytes { pointer in
        unsafe fwrite(pointer.baseAddress, 1, pointer.count, handle)
      }
      guard written == bytes.count else {
        throw Failure(reason: "fwrite failed: \(raw)")
      }
    }

    fileprivate static func remove(_ raw: Swift::String) {
      var status = stat()
      guard unsafe lstat(raw, &status) == 0 else { return }
      if (status.st_mode & S_IFMT) == S_IFDIR {
        if let handle = unsafe opendir(raw) {
          var names: [Swift::String] = []
          while let entry = unsafe readdir(handle) {
            let name = unsafe withUnsafeBytes(of: entry.pointee.d_name) { pointer in
              unsafe Swift::String(
                decoding: pointer.prefix(while: { $0 != 0 }),
                as: Swift::UTF8.self
              )
            }
            if name != "." && name != ".." { names.append(name) }
          }
          _ = unsafe closedir(handle)
          for name in names { remove(raw + "/" + name) }
        }
        _ = unsafe rmdir(raw)
      } else {
        _ = unsafe unlink(raw)
      }
    }
  }

#else

  extension Lint.Source.Fixture {
    fileprivate static func write(_ content: Swift::String, to raw: Swift::String) throws(Failure) {
      throw Failure(reason: "no file system on this platform")
    }
    fileprivate static func remove(_ raw: Swift::String) {}
  }

#endif
