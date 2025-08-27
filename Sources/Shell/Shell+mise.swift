import Foundation

extension Shell {
  /// Mise CLI wrapper for managing development tools and environments.
  public struct Mise: Sendable { let cliURL: URL }
}

extension Shell.Mise {
  /// Initialize Mise with optional CLI URL.
  ///
  /// - Parameter cliURL: Optional URL to the mise CLI executable. If nil, searches common paths.
  /// - Throws: Shell.Error if mise CLI cannot be found.
  public init(cliURL: URL? = .none) throws {
    do { self.init(cliURL: try cliURL ?? Shell.which(cliToolName: "mise")) }
    catch {
      let miseCLIPaths: [String] = [
        URL(
          fileURLWithPath: ".local/bin",
          isDirectory: true,
          relativeTo: FileManager.default.homeDirectoryForCurrentUser
        ), URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
        URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
      ]
      .map { $0.appending(path: "mise", directoryHint: .notDirectory) }.map { $0.path(percentEncoded: false) }
      let cliPath = miseCLIPaths.first { FileManager.default.isReadableFile(atPath: $0) }
      guard let cliPath else { throw Shell.Error("Can't find mise command line tool") }
      self.init(cliURL: URL(fileURLWithPath: cliPath, isDirectory: false))
    }
  }

  /// Run mise with the specified arguments.
  ///
  /// - Parameter arguments: Command line arguments to pass to mise.
  /// - Returns: Output from the mise command.
  /// - Throws: Shell.Error if the command fails.
  @discardableResult
  public func run(arguments: [String]) throws -> String { try Shell.run(executableURL: cliURL, arguments: arguments) }

  /// Find the path to a CLI tool using mise.
  ///
  /// - Parameter cliToolName: Name of the CLI tool to locate.
  /// - Returns: URL to the CLI tool executable.
  /// - Throws: Shell.Error if the tool cannot be found.
  public func which(cliToolName: String) throws -> URL {
    do {
      let cliPath: String = try run(arguments: ["which", cliToolName])
      return URL(fileURLWithPath: cliPath)
    }
    catch { throw Shell.Error("mise. Can't find \(cliToolName) command line tool") }
  }

  /// Install and use a specific version of a CLI tool.
  ///
  /// - Parameters:
  ///   - cliToolName: Name of the CLI tool to install/use.
  ///   - version: Version to install (defaults to "latest").
  /// - Throws: Shell.Error if the command fails.
  public func use(cliToolName: String, version: String = "latest") throws {
    try run(arguments: ["use", "\(cliToolName)@\(version)"])
  }
}
