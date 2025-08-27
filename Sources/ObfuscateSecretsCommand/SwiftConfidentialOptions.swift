import ArgumentParser
import Foundation

extension ObfuscateSecretsCommand {
  /// The path to a Confidential configuration file.
  public struct SwiftConfidentialOptions: ParsableArguments, Decodable {
    @Option(
      name: .customLong("swift-confidential-config"),
      help: "The path to a swift-confidential configuration file",
      transform: URL.init(fileURLWithPath:)
    )
    var configurationURL: URL

    /// Creates a new SwiftConfidentialOptions instance with default values.
    public init() {}
  }
}
