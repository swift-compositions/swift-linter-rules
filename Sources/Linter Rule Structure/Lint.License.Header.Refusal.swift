extension Lint.License.Header {

    public enum Refusal: Sendable, Equatable {
        case partial
        case interleaved
        case missingCopyright
        case missingLicenseGrant
    }
}
public import Linter_Primitives
