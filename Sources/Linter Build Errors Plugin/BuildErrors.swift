import Foundation
import PackagePlugin

/// Fails the build of a SwiftPM target on a finding of the rules in `Lint.Rule.Bundle.buildErrors`.
///
/// The check runs as a prebuild command, so it finishes before the target's sources compile: a finding stops the
/// build in seconds, where the compiler it guards against can take half an hour to give up. It prints
/// `path:line:column: error: message` lines, which Xcode and SwiftPM show as build errors.
@main
struct BuildErrors: BuildToolPlugin {

  /// The executable target the plugin depends on.
  static let tool = "Linter Build Errors"

  func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
    guard let module = target.sourceModule else { return [] }
    return try Self.commands(
      named: module.name,
      tool: context.tool(named: Self.tool).url,
      root: context.package.directoryURL,
      files: module.sourceFiles(withSuffix: ".swift").map(\.url),
      work: context.pluginWorkDirectoryURL
    )
  }

  static func commands(named name: String, tool: URL, root: URL, files: [URL], work: URL) -> [Command] {
    guard !files.isEmpty else { return [] }
    return [
      .prebuildCommand(
        displayName: "Linter build errors: \(name)",
        executable: tool,
        arguments: ["--root", root.path(percentEncoded: false)] + files.map { $0.path(percentEncoded: false) },
        outputFilesDirectory: work
      )
    ]
  }
}
