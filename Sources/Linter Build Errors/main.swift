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
        #if canImport(ucrt)
            var opened: UnsafeMutablePointer<FILE>?
            let status = unsafe fopen_s(&opened, stamp, "wb")
            let file = unsafe (status == 0 ? opened : nil)
        #else
            let file = unsafe fopen(stamp, "wb")
        #endif
        guard let handle = unsafe file else {
            print("swift-linter-build-errors: could not write the stamp file \(stamp)")
            exit(1)
        }
        _ = unsafe fclose(handle)
    }
    exit(outcome.status)
#endif
