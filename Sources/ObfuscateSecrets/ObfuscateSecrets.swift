import EnvSubst
import Foundation
import Shell

package struct ObfuscateSecrets {}

extension ObfuscateSecrets {
  package static func substituteEnvAndObfuscateWithCLI(
    inputFileURL: URL,
    outputFileURL: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    options: EnvSubst.Options = .strict,
    encoding: String.Encoding = .utf8,
    swiftConfidentialBinaryURL: URL? = .none,
    fileManager: FileManager = .default
  ) throws {
    let substitutedData = try substituteEnv(
      inputFileURL: inputFileURL,
      environment: environment,
      options: options,
      encoding: encoding,
      fileManager: fileManager
    )

    try obfuscateWithCLI(
      substitutedData,
      outputFileURL: outputFileURL,
      swiftConfidentialBinaryURL: swiftConfidentialBinaryURL,
      fileManager: fileManager
    )
  }

  private static func substituteEnv(
    inputFileURL: URL,
    environment: [String: String],
    options: EnvSubst.Options,
    encoding: String.Encoding,
    fileManager: FileManager
  ) throws -> Data {
    guard fileManager.isReadableFile(atPath: inputFileURL.path(percentEncoded: false)) else {
      throw Error(#"Unable to read configuration file at "\#(inputFileURL.path(percentEncoded: false))""#)
    }

    guard let inputString = String(bytes: try Data(contentsOf: inputFileURL), encoding: encoding) else {
      throw Error(#"Unable to read UTF-8 encoded configuration file at "\#(inputFileURL.path(percentEncoded: false))""#)
    }

    let substitutedString: String = try EnvSubst.substitute(inputString, environment: environment, options: options)

    guard let substitutedData = substitutedString.data(using: encoding) else {
      throw Error("Can't create Data from substituted string using \(encoding)")
    }

    return substitutedData
  }

  private static func obfuscateWithCLI(
    _ configurationData: Data,
    outputFileURL: URL,
    swiftConfidentialBinaryURL: URL? = .none,
    fileManager: FileManager
  ) throws {
    let tempDir = fileManager.temporaryDirectory.appending(path: "obfuscate-secrets", directoryHint: .isDirectory)
    defer { try? fileManager.removeItem(at: tempDir) }

    let tempFilename = "\(UUID().uuidString).yaml"
    let tempFileURL = tempDir.appending(path: tempFilename, directoryHint: .notDirectory)

    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try configurationData.write(to: tempFileURL, options: .atomic)

    let cli = try Shell.SwiftConfidential(cliURL: swiftConfidentialBinaryURL)

    try cli.obfuscate(configurationPath: tempFileURL.filePath, outputFilePath: outputFileURL.filePath)
  }
}

extension ObfuscateSecrets {
  struct Error: Swift.Error {
    let description: String

    init(_ description: String) { self.description = description }
  }
}

#if canImport(ConfidentialObfuscator)
  import ConfidentialObfuscator

  extension ObfuscateSecrets {
    package static func substituteEnvAndObfuscateWithLibrary(
      inputFileURL: URL,
      outputFileURL: URL,
      environment: [String: String] = ProcessInfo.processInfo.environment,
      options: EnvSubst.Options = .strict,
      encoding: String.Encoding = .utf8,
      fileManager: FileManager = .default
    ) throws {
      let substitutedData = try substituteEnv(
        inputFileURL: inputFileURL,
        environment: environment,
        options: options,
        encoding: encoding,
        fileManager: fileManager
      )

      try obfuscateWithLibrary(
        substitutedData,
        outputFileURL: outputFileURL,
        encoding: encoding,
        fileManager: fileManager
      )
    }

    private static func obfuscateWithLibrary(
      _ configurationData: Data,
      outputFileURL: URL,
      encoding: String.Encoding,
      fileManager: FileManager
    ) throws {
      let text: String = try ConfidentialObfuscator.obfuscate(configurationData: configurationData)

      guard fileManager.createFile(atPath: outputFileURL.path(percentEncoded: false), contents: .none) else {
        throw Error(#"Failed to create output file at "\#(outputFileURL.path(percentEncoded: false))""#)
      }

      try text.write(to: outputFileURL, atomically: true, encoding: encoding)
    }
  }
#endif
