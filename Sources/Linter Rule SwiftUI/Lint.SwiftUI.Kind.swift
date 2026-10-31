public import Lint

extension Lint.SwiftUI {

    public enum Kind: Sendable, Hashable {
        case withAnimation
        case animationModifier
        case stateIdentity
        case toolbarHidden
        case viewState
        case viewLogic
    }
}
