public import Lint

extension Lint.Rule.Bundle {

  public static let swiftUI: [Lint.Rule.Configuration] = [
    .enable(.`with animation`),
    .enable(.`animation modifier`),
    .enable(.`state identity`),
    .enable(.`toolbar hidden`),
    .enable(.`view state`),
    .enable(.`view logic`),
  ]
}
