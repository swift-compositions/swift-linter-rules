internal import Lint
package import SwiftSyntax

extension Lint.SQL {

  package enum Statement {}
}

extension Lint.SQL.Statement {

  package static let keywords: Swift::Set<Swift::String> = [
    "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "PRAGMA", "WITH",
    "REPLACE", "BEGIN",
  ]

  package static let clauses: Swift::Set<Swift::String> = [
    "FROM", "INTO", "VALUES", "WHERE", "SET", "TABLE", "INDEX", "TRIGGER", "TRANSACTION",
  ]

  package static func text(of literal: StringLiteralExprSyntax) -> Swift::String {
    var text = ""
    for segment in literal.segments {
      if let plain = segment.as(StringSegmentSyntax.self) {
        text += plain.content.text
      } else {
        text += " "
      }
    }
    return text
  }

  package static func leads(_ text: Swift::String) -> Swift::Bool {
    let words = Self.words(in: text)
    guard let first = words.first, first.leading else { return false }
    let upper = first.text.uppercased()
    guard keywords.contains(upper) else { return false }
    if first.text == upper { return true }
    return words.dropFirst().contains { clauses.contains($0.text.uppercased()) }
  }

  fileprivate static func words(in text: Swift::String) -> [(text: Swift::String, leading: Swift::Bool)] {
    var words: [(text: Swift::String, leading: Swift::Bool)] = []
    var current = ""
    var seenContent = false
    var currentLeading = false
    func flush() {
      if !current.isEmpty {
        words.append((current, currentLeading))
        current = ""
      }
    }
    for character in text {
      if character.isASCII, character.isLetter || character.isNumber || character == "_" {
        if current.isEmpty {
          currentLeading = !seenContent
        }
        current.append(character)
        seenContent = true
      } else {
        flush()
        if !character.isWhitespace {
          seenContent = true
        }
      }
    }
    flush()
    return words
  }

  package static func isDirectArgumentOfSQLMacro(_ literal: StringLiteralExprSyntax) -> Swift::Bool {
    guard let argument = literal.parent?.as(LabeledExprSyntax.self),
      let list = argument.parent?.as(LabeledExprListSyntax.self),
      let owner = list.parent
    else { return false }
    return isSQLMacro(owner)
  }

  package static func isSQLMacro(_ node: Syntax) -> Swift::Bool {
    if let expansion = node.as(MacroExpansionExprSyntax.self) {
      return expansion.macroName.text == "sql"
    }
    if let expansion = node.as(MacroExpansionDeclSyntax.self) {
      return expansion.macroName.text == "sql"
    }
    return false
  }
}
