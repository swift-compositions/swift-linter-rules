public import Lint

extension Lint.Rule {

  public struct Outcome: Sendable, Equatable, CustomStringConvertible {
    public let control: Swift::String
    public let expected: Swift::Int
    public let actual: Swift::Int
    public let expectedApplicability: Lint.Rule.Observation.Applicability
    public let actualApplicability: Lint.Rule.Observation.Applicability

    public var holds: Swift::Bool {
      expected == actual && expectedApplicability == actualApplicability
    }

    public var description: Swift::String {
      "\(control): expected \(expected) (\(expectedApplicability)), got \(actual) (\(actualApplicability))"
    }
  }

  public func outcomes() -> [Outcome] {
    controls.map { control in
      let parsed = Lint.Source.parsed(
        from: control.source,
        file: control.path.underlying,
        path: control.path
      )
      let observation = observe(parsed, .warning)
      return Outcome(
        control: control.id.underlying,
        expected: control.expectation.count,
        actual: observation.findings.count,
        expectedApplicability: control.applicability,
        actualApplicability: observation.applicability
      )
    }
  }
}
