import Foundation
import Shell

extension Shell { struct SwiftConfidential { let cliURL: URL } }

extension Shell.SwiftConfidential {
  init(cliURL: URL?) throws {
    try self.init(
      cliURL: cliURL
        ?? ((try? Shell.which(cliToolName: "swift-confidential"))
          ?? (try Shell.Mise().which(cliToolName: "swift-confidential")))
    )
  }

  private func run(arguments: [String]) throws {
    let _: Data = try Shell.run(executableURL: cliURL, arguments: arguments)
  }

  func obfuscate(configurationPath: String, outputFilePath: String) throws {
    let arguments: [[String]] = [["--configuration", configurationPath], ["--output", outputFilePath]]
    try run(arguments: arguments.flatMap(\.self))
  }
}
