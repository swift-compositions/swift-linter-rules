internal import Cardinal_Primitives
public import Linter_Primitives

extension Lint.License.Header {

  public static func recognize(in source: Swift.String) -> Recognition {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    var blocks: [(start: Swift.Int, lines: [Swift.Substring])] = []
    var current: (start: Swift.Int, lines: [Swift.Substring])?
    var reachedCode = false
    var laterLicenseMarker = false

    for (index, line) in lines.enumerated() {
      let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
      if !reachedCode, trimmed.hasPrefix("//") {
        if current == nil { current = (index, []) }
        current?.lines.append(line)
        continue
      }
      if !reachedCode, trimmed.isEmpty {
        if let block = current {
          blocks.append(block)
          current = nil
        }
        continue
      }
      if let block = current { blocks.append(block) }
      current = nil
      reachedCode = true
      if trimmed.hasPrefix("//") {
        let normalized = trimmed.lowercased()
        if normalized.contains("licensed under") || normalized.contains("copyright") {
          laterLicenseMarker = true
        }
      }
    }
    if let block = current { blocks.append(block) }

    var recognized: Lint.License.Header?
    for block in blocks {
      let text = block.lines.joined(separator: "\n")
      let normalized = text.lowercased()
      let mentionsCopyright = normalized.contains("copyright")
      let mentionsGrant = normalized.contains("licensed under")
      let mentionsLicense =
        mentionsCopyright || mentionsGrant || normalized.contains("license")
      guard mentionsLicense else { continue }
      guard mentionsCopyright else { return .refused(.missingCopyright) }
      guard mentionsGrant else { return .refused(.missingLicenseGrant) }
      guard recognized == nil else { return .refused(.interleaved) }
      recognized = Lint.License.Header(
        start: Cardinal(UInt(block.start)),
        count: Cardinal(UInt(block.lines.count)),
        text: text
      )
    }

    guard !laterLicenseMarker else { return .refused(.interleaved) }
    if let recognized { return .complete(recognized) }
    return .absent
  }
}
