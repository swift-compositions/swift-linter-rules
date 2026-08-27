public import Linter

extension Lint.License.Header {

  public enum Refusal: Sendable, Equatable {
    case partial
    case interleaved
    case missingCopyright
    case missingLicenseGrant
  }
}
