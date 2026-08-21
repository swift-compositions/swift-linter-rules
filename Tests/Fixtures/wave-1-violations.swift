let result1 = try? throwingCall()

func bare() throws -> Int { 0 }

func existential() throws(any Error) -> Int { 0 }

func setup() {
    let impl = factory()
    _ = impl
}

struct DebugFlags: OptionSet {
    let rawValue: Int
}

func openWrite() {}

struct CardinalTag {}
