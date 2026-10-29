#if LinterRuleBuildErrors
    import Lint
    import Linter_Rule_Build_Errors

    #if canImport(Darwin)
        internal import Darwin
    #elseif canImport(Glibc)
        internal import Glibc
    #elseif canImport(Musl)
        internal import Musl
    #elseif canImport(Android)
        internal import Android
    #elseif canImport(ucrt)
        internal import ucrt
    #endif

    let outcome = Lint.Build.run(
        arguments: [Swift::String](Swift::CommandLine.arguments.dropFirst()),
        rules: Lint.Rule.Bundle.buildErrors
    )
    for line in outcome.lines {
        print(line)
    }
    if let stamp = outcome.stamp {
        guard let handle = unsafe fopen(stamp, "wb") else {
            print("swift-linter-build-errors: could not write the stamp file \(stamp)")
            exit(1)
        }
        _ = unsafe fclose(handle)
    }
    exit(outcome.status)
#endif
