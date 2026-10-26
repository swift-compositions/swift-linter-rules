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
#endif

let outcome = Lint.Build.run(
  arguments: [Swift::String](Swift::CommandLine.arguments.dropFirst()),
  rules: Lint.Rule.Bundle.buildErrors
)
for line in outcome.lines {
  print(line)
}
if let stamp = outcome.stamp {
  let descriptor = unsafe open(stamp, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
  if descriptor < 0 {
    print("swift-linter-build-errors: could not write the stamp file \(stamp)")
    exit(1)
  }
  close(descriptor)
}
exit(outcome.status)
