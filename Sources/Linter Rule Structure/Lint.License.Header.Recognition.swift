public import Linter

extension Lint.License.Header {

  public enum Recognition: Sendable, Equatable {
    case absent
    case complete(Lint.License.Header)
    case refused(Refusal)
  }
}
