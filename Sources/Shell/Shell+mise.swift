import Foundation

extension Shell { public struct Mise: Sendable { let cliURL: URL } }

extension Shell.Mise {
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

  @discardableResult
  public func run(arguments: [String]) throws -> String { try Shell.run(executableURL: cliURL, arguments: arguments) }

  public func which(cliToolName: String) throws -> URL {
    do {
      let cliPath: String = try run(arguments: ["which", cliToolName])
      return URL(fileURLWithPath: cliPath)
    }
    catch { throw Shell.Error("mise. Can't find \(cliToolName) command line tool") }
  }

  public func use(cliToolName: String, version: String = "latest") throws {
    try run(arguments: ["use", "\(cliToolName)@\(version)"])
  }
}
