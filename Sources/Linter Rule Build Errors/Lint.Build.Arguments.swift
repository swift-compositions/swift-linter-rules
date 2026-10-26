public import Lint

extension Lint.Build {

  /// What the tool is asked to check: the directory that file paths are made relative to, and the Swift files.
  public struct Arguments: Sendable, Equatable {

    public let root: Swift::String

    public let files: [Swift::String]

    public init(root: Swift::String, files: [Swift::String]) {
      self.root = root
      self.files = files
    }
  }
}

extension Lint.Build.Arguments {

  public static let usage: Swift::String = "usage: swift-linter-build-errors --root <directory> <file.swift> ..."

  /// Reads `--root <directory>` and the files after it. A call with no file is refused, since a build check that
  /// names nothing is a wiring mistake and not a clean result.
  public static func parse(_ arguments: [Swift::String]) throws(Error) -> Self {
    var root: Swift::String?
    var files: [Swift::String] = []
    var remaining = arguments.makeIterator()
    while let argument = remaining.next() {
      if argument == "--root" {
        guard let value = remaining.next() else { throw .missing(option: argument) }
        root = value
      } else if argument.hasPrefix("--") {
        throw .unknown(option: argument)
      } else {
        files.append(argument)
      }
    }
    guard let root else { throw .missing(option: "--root") }
    guard !files.isEmpty else { throw .noFiles }
    return Self(root: root, files: files)
  }
}
