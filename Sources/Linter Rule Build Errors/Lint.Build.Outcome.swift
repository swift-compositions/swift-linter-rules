public import Lint

extension Lint.Build {

  /// What the tool prints, one line each, and the status it exits with: 0 when no error was found, 1 when one was,
  /// and 64 when the arguments were refused.
  public struct Outcome: Sendable, Equatable {

    public let lines: [Swift::String]

    public let status: Swift::Int32

    public init(lines: [Swift::String], status: Swift::Int32) {
      self.lines = lines
      self.status = status
    }
  }
}
