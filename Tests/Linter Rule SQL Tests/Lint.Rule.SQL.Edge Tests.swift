import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_SQL

extension Lint.Rule {
  @Suite
  struct `sql edge Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Exemption {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`sql edge Tests` {
  static func findings(
    _ source: Swift::String,
    file: Swift::String = "Sources/Affairs SQLite/Letter+SQLite.swift"
  ) -> [Diagnostic.Record] {
    Lint.Rule.`sql edge`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
  }
}

extension Lint.Rule.`sql edge Tests`.Unit {
  @Test(arguments: ["fetchAll", "fetchOne", "fetchCount", "fetchSet", "fetchCursor", "execute"])
  func `each execution call in a query function fires`(call: Swift::String) {
    let findings = Lint.Rule.`sql edge Tests`.findings(
      """
      extension Letter {
        static func pending(_ db: SQLite.Connection) throws {
          _ = try Letter.where(\\.isPending).\(call)(db)
        }
      }
      """
    )
    #expect(findings.count == 1)
    #expect(findings.first?.message.contains("`Letter.pending(_:)`") == true)
  }

  @Test
  func `a stored connection does not make a method an edge`() {
    let findings = Lint.Rule.`sql edge Tests`.findings(
      """
      struct Storage {
        let database: SQLite.Connection
        func history() throws -> [Row] { try Row.all.fetchAll(database) }
      }
      """
    )
    #expect(findings.count == 1)
  }

  @Test
  func `read and write closures are edges`() {
    let findings = Lint.Rule.`sql edge Tests`.findings(
      """
      extension Library {
        static func sqlite(_ database: SQLite.Database) -> Self {
          Self(
            list: { try await database.read { db in try Letter.pending.fetchAll(db) } },
            mark: { id in try await database.write { try Mark.insert { id }.execute($0) } },
            raw: { try database.writeWithoutTransaction { db in try Letter.delete().execute(db) } }
          )
        }
      }
      """
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `a fetch key request is an edge`() {
    let findings = Lint.Rule.`sql edge Tests`.findings(
      """
      struct Request: FetchKeyRequest {
        func fetch(_ db: SQLite.Connection) throws -> [Letter] { try Letter.all.fetchAll(db) }
      }
      extension Other: SQLite.FetchKeyRequest {
        func fetch(_ db: SQLite.Connection) throws -> Int { try Letter.all.fetchCount(db) }
      }
      """
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `message names the declaration and the fix`() {
    let message = Lint.Rule.`sql edge Tests`.findings("func f(db: C) { try? T.all.execute(db) }").first?.message ?? ""
    #expect(message.contains("`f(db:)`"))
    #expect(message.contains("Fix:"))
  }
}

extension Lint.Rule.`sql edge Tests`.`Edge Case` {
  @Test
  func `a function declared inside a read closure is still at the edge`() {
    let findings = Lint.Rule.`sql edge Tests`.findings(
      """
      func load(_ database: SQLite.Database) async throws -> Int {
        try await database.read { db in
          func count() throws -> Int { try Letter.all.fetchCount(db) }
          return try count()
        }
      }
      """
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `a closure passed to another call is not an edge`() {
    let findings = Lint.Rule.`sql edge Tests`.findings(
      """
      func load(_ db: SQLite.Connection) throws -> [Int] {
        try ids.map { try Letter.find($0).fetchOne(db) }
      }
      """
    )
    #expect(findings.count == 1)
  }

  @Test
  func `fetch that is not a request's is not an edge`() {
    let findings = Lint.Rule.`sql edge Tests`.findings(
      """
      struct Listing {
        static func fetch(_ db: SQLite.Connection) throws -> [Letter] { try Letter.all.fetchAll(db) }
      }
      """
    )
    #expect(findings.count == 1)
  }

  @Test
  func `free function calls named like executions do not fire`() {
    #expect(Lint.Rule.`sql edge Tests`.findings("func f() { execute(plan) }").isEmpty)
  }
}

extension Lint.Rule.`sql edge Tests`.Exemption {
  @Test(arguments: [
    "Sources/Affairs Schema/Schema+Sync.swift",
    "Tests/Affairs Tests/Letter.Tests.swift",
    "Hosts/Laurie/App.swift",
  ])
  func `schema targets, tests and hosts are inapplicable`(file: Swift::String) {
    let observation = Lint.Rule.`sql edge`.observe(
      Lint.Source.parsed(from: "func f(_ db: C) throws { try T.all.execute(db) }", file: file),
      .warning
    )
    #expect(observation.findings.isEmpty)
    #expect(observation.applicability == .inapplicable)
  }

  @Test
  func `an executable target is an edge`() throws {
    let fixture = try Lint.Source.Fixture(files: [
      "Sources/db/main.swift": "print(1)",
      "Sources/db/Command.swift": "func run(_ db: C) throws { try T.all.execute(db) }",
    ])
    let observation = Lint.Rule.`sql edge`.observe(fixture.parsed("Sources/db/Command.swift"), .warning)
    #expect(observation.findings.isEmpty)
    #expect(observation.applicability == .inapplicable)
  }
}

extension Lint.Rule.`sql edge Tests`.Integration {
  @Test
  func `controls hold`() {
    let outcomes = Lint.Rule.`sql edge`.outcomes()
    #expect(outcomes.contains { $0.expected > 0 })
    for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
  }
}
