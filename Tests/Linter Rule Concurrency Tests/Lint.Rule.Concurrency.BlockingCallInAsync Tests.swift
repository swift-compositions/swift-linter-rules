import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Concurrency

enum `Lint.Rule Tests` {}

extension `Lint.Rule Tests` {
    @Suite
    struct `blocking call in async Tests` {}
}

extension `Lint.Rule Tests`.`blocking call in async Tests` {
    static func count(_ source: Swift::String, file: Swift::String = "Sources/Fetch/Fetch.swift") -> Swift::Int {
        Lint.Rule.`blocking call in async`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings.count
    }

    @Test func `controls hold`() {
        for outcome in Lint.Rule.`blocking call in async`.outcomes() {
            #expect(outcome.holds, "\(outcome)")
        }
    }

    @Test func `a blocking read or wait in an async function is flagged`() {
        #expect(Self.count("func f() async { let d = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit() }") == 2)
    }

    @Test func `a blocking call in an async initializer or accessor is flagged`() {
        #expect(Self.count("struct S { init() async { Thread.sleep(forTimeInterval: 1) } }") == 1)
        #expect(Self.count("struct S { var x: Int { get async { usleep(10); return 1 } } }") == 1)
    }

    @Test func `a blocking call in an async closure or a Task is flagged`() {
        #expect(Self.count("let c = { () async in semaphore.wait() }") == 1)
        #expect(Self.count("Task { let d = try Data(contentsOf: url) }") == 1)
        #expect(Self.count("let c = { await x(); group.wait() }") == 1)
    }

    @Test func `the stack's own blocking calls are flagged too`() {
        #expect(Self.count("func f() async throws { let o = try Process.Spawn.run(c); let s = try handle.wait() }") == 2)
        #expect(Self.count("func f() async { let s = try String(contentsOfFile: p) }") == 1)
    }

    @Test func `@concurrent does not excuse a blocking call: it still holds a cooperative thread`() {
        #expect(Self.count("@concurrent func f() async { process.waitUntilExit() }") == 1)
    }

    @Test func `a blocking call handed to a thread pool in a synchronous closure is not flagged`() {
        #expect(Self.count("func f() async throws { let o = try await Kernel.Thread.Pool.shared.run { Result { try Process.Spawn.run(c) } } }") == 0)
    }

    @Test func `an enum case named wait is not a blocking call`() {
        #expect(Self.count("func f() async { send(.wait(id)); let a = Action.wait(for: d); let b = Effect.Kind.wait(x) }") == 0)
        #expect(Self.count("func f() async { _ = semaphore.wait(timeout: .now() + 1) }") == 1)
    }

    @Test func `an awaited call of the same name is not blocking`() {
        #expect(Self.count("func f() async { await gate.wait(); try await Task.sleep(for: .seconds(1)); await clock.sleep(until: d) }") == 0)
    }

    @Test func `a test may block: its thread is the test's own`() {
        #expect(Self.count("func f() async throws { let d = try Data(contentsOf: url) }", file: "Tests/Fetch Tests/Fetch Tests.swift") == 0)
    }

    @Test func `synchronous code may block`() {
        #expect(Self.count("func f() { process.waitUntilExit(); Thread.sleep(forTimeInterval: 1) }") == 0)
        #expect(Self.count("func f() async { let c = { process.waitUntilExit() } }") == 0)
    }
}
