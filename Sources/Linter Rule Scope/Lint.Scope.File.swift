package import Lint

#if canImport(Darwin)
  internal import Darwin
#elseif canImport(Glibc)
  internal import Glibc
#elseif canImport(Musl)
  internal import Musl
#elseif canImport(Android)
  internal import Android
#endif

extension Lint.Scope {

  package enum File {}
}

extension Lint.Scope.File {

  package static let skipped: Swift::Set<Swift::String> = [
    ".build", ".git", ".swiftpm", ".claude", "node_modules", "checkouts", "DerivedData",
  ]

  package static func swiftFiles(under directory: Swift::String) -> [Swift::String] {
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

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android)

  extension Lint.Scope.File {

    package static func text(at raw: Swift::String) -> Swift::String? {
      guard let handle = unsafe fopen(raw, "rb") else { return nil }
      defer { _ = unsafe fclose(handle) }
      var bytes: [Swift::UInt8] = []
      var buffer = [Swift::UInt8](repeating: 0, count: 4096)
      while true {
        let count = buffer.withUnsafeMutableBytes { pointer in
          unsafe fread(pointer.baseAddress, 1, pointer.count, handle)
        }
        guard count > 0 else { break }
        bytes.append(contentsOf: buffer[0..<count])
      }
      return Swift::String(decoding: bytes, as: Swift::UTF8.self)
    }

    package static func isDirectory(_ raw: Swift::String) -> Swift::Bool {
      var status = stat()
      guard unsafe stat(raw, &status) == 0 else { return false }
      return (status.st_mode & S_IFMT) == S_IFDIR
    }

    package static func isFile(_ raw: Swift::String) -> Swift::Bool {
      var status = stat()
      guard unsafe stat(raw, &status) == 0 else { return false }
      return (status.st_mode & S_IFMT) == S_IFREG
    }

    package static func entries(in directory: Swift::String) -> [Swift::String] {
      guard let handle = unsafe opendir(directory) else { return [] }
      defer { _ = unsafe closedir(handle) }
      var names: [Swift::String] = []
      while let entry = unsafe readdir(handle) {
        let name = unsafe withUnsafeBytes(of: entry.pointee.d_name) { pointer in
          unsafe Swift::String(
            decoding: pointer.prefix(while: { $0 != 0 }),
            as: Swift::UTF8.self
          )
        }
        if name == "." || name == ".." { continue }
        names.append(name)
      }
      return names.sorted()
    }
  }

#else

  extension Lint.Scope.File {
    package static func text(at raw: Swift::String) -> Swift::String? { nil }
    package static func isDirectory(_ raw: Swift::String) -> Swift::Bool { false }
    package static func isFile(_ raw: Swift::String) -> Swift::Bool { false }
    package static func entries(in directory: Swift::String) -> [Swift::String] { [] }
  }

#endif

extension Lint.Scope.File {

  package static func root(of source: borrowing Lint.Source.Parsed) -> Swift::String? {
    let relative = source.path.underlying
    let absolute = source.file.filePath
    guard !relative.isEmpty, absolute.hasPrefix("/"), absolute.hasSuffix("/" + relative) else {
      return nil
    }
    let root = Swift::String(absolute.dropLast(relative.count + 1))
    guard !root.isEmpty, isDirectory(root) else { return nil }
    return root
  }
}
