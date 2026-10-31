public import Lint
public import SwiftSyntax

extension Lint.SwiftUI {

    public struct Hit {
        public let node: Syntax
        public let kind: Kind
        public let detail: Swift::String
    }
}
