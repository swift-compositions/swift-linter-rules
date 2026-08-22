public import Linter_Primitives

extension Lint.Rule {

  public func rewritten(_ source: borrowing Lint.Source.Parsed) -> Swift.String? {
    guard
      case .edits(let edits) = repair(source),
      edits.count == 1,
      case .rewrite(let path, let contents) = edits[0],
      path == source.path
    else {
      return nil
    }
    return contents
  }
}
