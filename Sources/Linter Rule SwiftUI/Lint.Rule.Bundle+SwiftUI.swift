public import Lint

extension Lint.Rule.Bundle {

    public static let swiftUI: [Lint.Rule.Configuration] = [
        .enable(.`toolbar hidden`)
    ]
}
