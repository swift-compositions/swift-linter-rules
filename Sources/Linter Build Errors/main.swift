#if LinterRuleBuildErrors
    import Byte
    import File_System
    import Lint
    import Linter_Rule_Build_Errors
    import Process

    let outcome = Lint.Build.run(
        arguments: [Swift::String](Swift::CommandLine.arguments.dropFirst()),
        rules: Lint.Rule.Bundle.buildErrors
    )
    for line in outcome.lines {
        print(line)
    }
    if let stamp = outcome.stamp {
        do {
            let empty: [Byte] = []
            try File.System.Write.Atomic.write(empty.span, to: File.Path(stamp))
        } catch {
            print("swift-linter-build-errors: could not write the stamp file \(stamp)")
            Process.exit(1)
        }
    }
    Process.exit(outcome.status)
#endif
