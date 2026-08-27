import Foundation
import PackagePlugin

@main
struct SemanticVersionBuildToolPlugin {
  func createBuildCommands(packageDirectoryURL: URL, pluginWorkDirectoryURL: URL, targetName: String, toolURL: URL )
    -> [Command]
  {
    // Find the version file — prefer .config/semantic-version/version, fall back to .version
    let candidates: [URL] = [
      packageDirectoryURL.appending(path: ".config/semantic-version/version", directoryHint: .notDirectory),
      packageDirectoryURL.appending(path: ".version", directoryHint: .notDirectory),
    ]
    guard
      let versionFile = candidates.first(where: {
        FileManager.default.isReadableFile(atPath: $0.path(percentEncoded: false))
      })
    else { return [] }

    // Output directory and file
    let outputDirectory = pluginWorkDirectoryURL.appending(path: "GeneratedSources", directoryHint: .isDirectory)
    let outputFile = outputDirectory.appending(
      path: "\(targetName)Version.generated.swift",
      directoryHint: .notDirectory,
    )

    return [
      .buildCommand(
        displayName: "Generate \(targetName) Version",
        executable: toolURL,
        arguments: [
          "--version-file", versionFile.path(percentEncoded: false), "--target-name", targetName, "--output",
          outputFile.path(percentEncoded: false),
        ],
        inputFiles: [versionFile],
        outputFiles: [outputFile],
      )
    ]
  }
}

extension SemanticVersionBuildToolPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    // Only apply to source targets
    guard let target = target as? SourceModuleTarget else { return [] }

    return createBuildCommands(
      packageDirectoryURL: context.package.directoryURL,
      pluginWorkDirectoryURL: context.pluginWorkDirectoryURL,
      targetName: target.name,
      toolURL: try context.tool(named: "SemanticVersionGenerator").url,
    )
  }
}

#if canImport(XcodeProjectPlugin)
  import XcodeProjectPlugin

  extension SemanticVersionBuildToolPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
      createBuildCommands(
        packageDirectoryURL: context.xcodeProject.directoryURL,
        pluginWorkDirectoryURL: context.pluginWorkDirectoryURL,
        targetName: target.displayName,
        toolURL: try context.tool(named: "SemanticVersionGenerator").url,
      )
    }
  }
#endif
