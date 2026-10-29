import Lint
import Linter_Rule_Scope
import Linter_Rules_Test_Support
import Testing

@testable import Linter_Rule_Package

@Suite
struct `conflicting dependency url Tests` {
    @Suite struct Unit {}
    @Suite struct Exemption {}
    @Suite struct `Edge Case` {}
}

extension `conflicting dependency url Tests` {
    static func manifest(_ dependencies: Swift::String) -> Swift::String {
        """
        // swift-tools-version: 6.4
        import PackageDescription

        let package = Package(
            name: "fixture",
            dependencies: [
        \(dependencies)
            ]
        )
        """
    }

    static func resolved(_ pins: [(identity: Swift::String, location: Swift::String)]) -> Swift::String {
        let objects = pins.map { pin in
            """
                {
                  "identity" : "\(pin.identity)",
                  "kind" : "remoteSourceControl",
                  "location" : "\(pin.location)",
                  "state" : {
                    "branch" : "main",
                    "revision" : "6471fa9000000000000000000000000000000000"
                  }
                }
            """
        }
        return """
            {
              "originHash" : "0",
              "pins" : [
            \(objects.joined(separator: ",\n"))
              ],
              "version" : 3
            }
            """
    }

    static func findings(_ fixture: borrowing Lint.Source.Fixture) -> [Diagnostic.Record] {
        Lint.Rule.`conflicting dependency url`.observe(fixture.parsed("Package.swift"), .warning).findings
    }

    /// The line of a finding, read from its `fileID:line:column` description.
    static func line(_ record: Diagnostic.Record) -> Swift::String {
        record.location.description.split(separator: ":").dropLast().last.map(Swift::String.init) ?? ""
    }
}

extension `conflicting dependency url Tests`.Unit {
    @Test
    func `conflict in the root manifest is flagged`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": `conflicting dependency url Tests`.manifest(
                #"        .package(url: "https://github.com/swift-molecules/swift-interface.git", branch: "main"),"#
            ),
            "Package.resolved": `conflicting dependency url Tests`.resolved([
                ("swift-interface", "https://github.com/coenttb/swift-interface.git")
            ]),
        ])
        let findings = `conflicting dependency url Tests`.findings(fixture)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "conflicting dependency url")
            #expect(`conflicting dependency url Tests`.line(findings[0]) == "7")
            #expect(findings[0].message.contains("`swift-interface` is pinned at `https://github.com/coenttb/swift-interface.git`"))
            #expect(findings[0].message.contains("this manifest spells it `https://github.com/swift-molecules/swift-interface.git`"))
        }
    }

    @Test
    func `conflict in a checkout manifest is flagged`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": `conflicting dependency url Tests`.manifest(
                """
                        .package(url: "https://github.com/coenttb/swift-interface.git", branch: "main"),
                        .package(url: "https://github.com/coenttb/swift-interface-composable-architecture", branch: "main"),
                """
            ),
            "Package.resolved": `conflicting dependency url Tests`.resolved([
                ("swift-interface", "https://github.com/coenttb/swift-interface.git"),
                ("swift-interface-composable-architecture", "https://github.com/coenttb/swift-interface-composable-architecture"),
            ]),
            ".build/checkouts/swift-interface-composable-architecture/Package.swift":
                `conflicting dependency url Tests`.manifest(
                    #"        .package(url: "https://github.com/swift-molecules/swift-interface.git", branch: "main"),"#
                ),
            ".build/checkouts/swift-interface/Package.swift": `conflicting dependency url Tests`.manifest(""),
        ])
        let findings = `conflicting dependency url Tests`.findings(fixture)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(`conflicting dependency url Tests`.line(findings[0]) == "7")
            #expect(
                findings[0].message.contains(
                    "`.build/checkouts/swift-interface-composable-architecture/Package.swift:7` spells it "
                        + "`https://github.com/swift-molecules/swift-interface.git`"
                )
            )
        }
    }

    @Test
    func `checkout directory is found case-insensitively`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": `conflicting dependency url Tests`.manifest(
                #"        .package(url: "https://github.com/pointfreeco/Swift-Dependencies", from: "1.0.0"),"#
            ),
            "Package.resolved": `conflicting dependency url Tests`.resolved([
                ("swift-dependencies", "https://github.com/pointfreeco/Swift-Dependencies"),
                ("swift-clocks", "https://github.com/pointfreeco/swift-clocks"),
            ]),
            ".build/checkouts/Swift-Dependencies/Package.swift": `conflicting dependency url Tests`.manifest(
                #"        .package(url: "https://github.com/someone-else/swift-clocks", from: "1.0.0"),"#
            ),
        ])
        let findings = `conflicting dependency url Tests`.findings(fixture)
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("`swift-clocks`") == true)
    }
}

extension `conflicting dependency url Tests`.Exemption {
    @Test
    func `canonically equal spellings are clean`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": `conflicting dependency url Tests`.manifest(
                """
                        .package(url: "https://github.com/Coenttb/Swift-Interface/", branch: "main"),
                        .package(url: "https://github.com/coenttb/swift-interface-composable-architecture", branch: "main"),
                """
            ),
            "Package.resolved": `conflicting dependency url Tests`.resolved([
                ("swift-interface", "https://github.com/coenttb/swift-interface.git"),
                ("swift-interface-composable-architecture", "https://github.com/coenttb/swift-interface-composable-architecture"),
            ]),
            ".build/checkouts/swift-interface-composable-architecture/Package.swift":
                `conflicting dependency url Tests`.manifest(
                    """
                            .package(url: "git@github.com:coenttb/swift-interface.git", branch: "main"),
                            .package(url: "ssh://git@github.com/coenttb/swift-interface", branch: "main"),
                            .package(url: "http://github.com/COENTTB/swift-interface.git/", branch: "main"),
                    """
                ),
        ])
        #expect(`conflicting dependency url Tests`.findings(fixture).isEmpty)
    }

    @Test
    func `unpinned identity spelled two ways is clean`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": `conflicting dependency url Tests`.manifest(
                """
                        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
                        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
                """
            ),
            "Package.resolved": `conflicting dependency url Tests`.resolved([
                ("swift-dependencies", "https://github.com/pointfreeco/swift-dependencies")
            ]),
            ".build/checkouts/swift-dependencies/Package.swift": `conflicting dependency url Tests`.manifest(
                #"        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),"#
            ),
        ])
        #expect(`conflicting dependency url Tests`.findings(fixture).isEmpty)
    }

    @Test
    func `absent Package resolved is clean`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": `conflicting dependency url Tests`.manifest(
                #"        .package(url: "https://github.com/swift-molecules/swift-interface.git", branch: "main"),"#
            )
        ])
        #expect(`conflicting dependency url Tests`.findings(fixture).isEmpty)
    }

    @Test
    func `non-manifest files never fire`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Sources/A/File.swift": #"let url = "https://github.com/swift-molecules/swift-interface.git""#,
            "Sources/A/Package.resolved": `conflicting dependency url Tests`.resolved([
                ("swift-interface", "https://github.com/coenttb/swift-interface.git")
            ]),
        ])
        let parsed = fixture.parsed("Sources/A/File.swift")
        #expect(Lint.Rule.`conflicting dependency url`.observe(parsed, .warning).findings.isEmpty)
    }

    @Test
    func `controls hold`() {
        for outcome in Lint.Rule.`conflicting dependency url`.outcomes() {
            #expect(outcome.holds, "\(outcome)")
        }
    }
}

extension `conflicting dependency url Tests`.`Edge Case` {
    @Test
    func `canonical location drops scheme user git suffix and slash`() {
        let expected = "github.com/coenttb/swift-interface"
        #expect(packageConflictingDependencyURLCanonical("https://github.com/coenttb/swift-interface.git") == expected)
        #expect(packageConflictingDependencyURLCanonical("git@github.com:coenttb/swift-interface.git") == expected)
        #expect(packageConflictingDependencyURLCanonical("ssh://git@github.com/coenttb/swift-interface") == expected)
        #expect(packageConflictingDependencyURLCanonical("HTTPS://GitHub.com/Coenttb/Swift-Interface/") == expected)
        #expect(
            packageConflictingDependencyURLCanonical("https://github.com/swift-molecules/swift-interface.git")
                != expected
        )
    }

    @Test
    func `version 1 and escaped-slash resolutions are read`() {
        let version1 = """
            {
              "object": {
                "pins": [
                  {
                    "package": "Swift-Interface",
                    "repositoryURL": "https:\\/\\/github.com\\/coenttb\\/Swift-Interface.git",
                    "state": { "branch": "main", "revision": "0", "version": null }
                  }
                ]
              },
              "version": 1
            }
            """
        #expect(
            packageConflictingDependencyURLPins(version1)
                == ["swift-interface": "https://github.com/coenttb/Swift-Interface.git"]
        )
    }

    @Test
    func `several conflicting spellings each report`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": `conflicting dependency url Tests`.manifest(
                """
                        .package(url: "https://github.com/swift-molecules/swift-interface.git", branch: "main"),
                        .package(url: "https://github.com/swift-atoms/swift-interface.git", branch: "main"),
                """
            ),
            "Package.resolved": `conflicting dependency url Tests`.resolved([
                ("swift-interface", "https://github.com/coenttb/swift-interface.git")
            ]),
        ])
        let findings = `conflicting dependency url Tests`.findings(fixture)
        #expect(findings.map(`conflicting dependency url Tests`.line) == ["7", "8"])
    }
}
