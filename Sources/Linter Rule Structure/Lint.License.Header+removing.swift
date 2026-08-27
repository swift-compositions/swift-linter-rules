internal import Cardinal
public import Linter

extension Lint.License.Header {

  public func removing(from source: Swift.String) -> Swift.String? {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    guard start + count <= Cardinal(UInt(lines.count)) else {
      return nil
    }
    var result = Swift.Array(lines.prefix(start))
    var suffix = lines.dropFirst(start + count)
    while suffix.first?.drop(while: { $0 == " " || $0 == "\t" }).isEmpty == true {
      suffix = suffix.dropFirst()
    }
    if !result.isEmpty, !suffix.isEmpty,
      result.last?.drop(while: { $0 == " " || $0 == "\t" }).isEmpty == false
    {
      result.append("")
    }
    result.append(contentsOf: suffix)
    return result.joined(separator: "\n")
  }
}
