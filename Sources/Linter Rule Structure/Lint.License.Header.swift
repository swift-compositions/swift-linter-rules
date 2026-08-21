extension Lint.License {

    public struct Header: Sendable, Equatable {

        public let startLine: Swift.Int

        public let lineCount: Swift.Int

        public let text: Swift.String

        @inlinable
        public init(startLine: Swift.Int, lineCount: Swift.Int, text: Swift.String) {
            self.startLine = startLine
            self.lineCount = lineCount
            self.text = text
        }
    }
}
public import Linter_Primitives
