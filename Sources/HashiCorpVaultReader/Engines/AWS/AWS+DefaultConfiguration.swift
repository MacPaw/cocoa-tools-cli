extension HashiCorpVaultReader.Engine.AWS {
  /// Default configuration for AWS engine.
  public struct DefaultConfiguration {
    /// The path to the AWS engine to configure, such as `aws`.
    ///
    /// Defaults to `aws`.
    public let defaultEnginePath: String

    /// Initialize default configuration.
    ///
    /// - Parameter defaultEnginePath: The default engine path (defaults to "aws").
    public init(defaultEnginePath: String = "aws") { self.defaultEnginePath = defaultEnginePath }
  }
}

private typealias DefaultConfiguration = HashiCorpVaultReader.Engine.AWS.DefaultConfiguration

extension DefaultConfiguration: Decodable {
  private enum CodingKeys: String, CodingKey { case defaultEnginePath }

  /// Initialize from decoder.
  ///
  /// - Parameter decoder: The decoder to read data from.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaultEnginePath = try container.decodeIfPresent(String.self, forKey: .defaultEnginePath) ?? "aws"

    self.init(defaultEnginePath: defaultEnginePath)
  }
}

extension DefaultConfiguration: Equatable {}
extension DefaultConfiguration: Sendable {}
extension DefaultConfiguration: HashiCorpVaultEngineDefaultConfigurationProtocol {}
