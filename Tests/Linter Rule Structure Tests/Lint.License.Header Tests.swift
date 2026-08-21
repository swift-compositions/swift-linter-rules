import Linter_Rule_Structure
import Testing

extension Lint.License.Header {

    @Suite
    struct Test {

        @Test
        func `complete leading block is recognized and removed`() {
            let source = """
                // Copyright (c) 2026 Example
                // Licensed under Apache License v2.0

                struct Value {}
                """
            guard case .complete(let header) = Lint.License.Header.recognize(in: source) else {
                Issue.record("expected a complete header")
                return
            }
            #expect(header.removing(from: source) == "struct Value {}")
        }

        @Test
        func `ordinary leading comments are not license blocks`() {
            #expect(
                Lint.License.Header.recognize(in: "// Implementation note\nstruct Value {}")
                    == .absent
            )
        }

        @Test
        func `license words in code are not headers`() {
            #expect(
                Lint.License.Header.recognize(
                    in: "let license = \"Licensed under a commercial agreement\""
                ) == .absent
            )
        }

        @Test
        func `manifest tools directive is preserved when a later leading header is removed`() {
            let source = """
                // swift-tools-version: 6.4

                // Copyright (c) 2026 Example
                // Licensed under Apache License v2.0

                import PackageDescription
                """
            guard case .complete(let header) = Lint.License.Header.recognize(in: source) else {
                Issue.record("expected a complete header after the tools directive")
                return
            }
            #expect(
                header.removing(from: source)
                    == "// swift-tools-version: 6.4\n\nimport PackageDescription"
            )
        }

        @Test
        func `partial leading license block refuses removal`() {
            #expect(
                Lint.License.Header.recognize(
                    in: "// Licensed under Apache License v2.0\nstruct Value {}"
                ) == .refused(.missingCopyright)
            )
        }

        @Test
        func `interleaved license marker refuses removal`() {
            #expect(
                Lint.License.Header.recognize(
                    in: "struct Value {}\n// Licensed under Apache License v2.0"
                ) == .refused(.interleaved)
            )
        }
    }
}
