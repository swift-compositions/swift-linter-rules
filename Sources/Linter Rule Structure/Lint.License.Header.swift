public import Cardinal
public import Linter

extension Lint.License {

  public struct Header: Sendable, Equatable {

    public let start: Cardinal

    public let count: Cardinal

    public let text: Swift.String

    @inlinable
    public init(start: Cardinal, count: Cardinal, text: Swift.String) {
      self.start = start
      self.count = count
      self.text = text
    }
  }
}
