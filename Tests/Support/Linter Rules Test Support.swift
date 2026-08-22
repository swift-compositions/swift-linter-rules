public import Byte_Primitives
public import Linter_Primitives
import SwiftParser
import SwiftSyntax

extension Lint.Source {

  public static func parsed(
    from source: Swift.String,
    file: Swift.String = "test.swift",
    path: Lint.Source.Path? = nil,
    types: Swift.Set<Swift.String> = []
  ) -> Lint.Source.Parsed {
    let tree = Parser.parse(source: source)
    let converter = SourceLocationConverter(fileName: file, tree: tree)
    var manager = Source.Manager()
    let id = manager.register(
      fileID: file,
      filePath: file,
      content: source.utf8.map(Byte.init)
    )
    return Self.Parsed(
      file: manager.file(for: id),
      path: path ?? Self.Path(file),
      tree: tree,
      converter: converter,
      types: types
    )
  }
}
