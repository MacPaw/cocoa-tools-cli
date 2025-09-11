import Foundation

extension HashiCorpVaultReader.Engine.AWS {
  /// Element configuration for AWS engine operations.
  public struct Element {
    /// The path to the AWS engine to use, such as `aws`.
    public var enginePath: String
    /// Specifies the name of the role to generate credentials against.
    public var role: String
    /// The key within the credentials to retrieve.
    public var key: String
  }
}

private typealias Element = HashiCorpVaultReader.Engine.AWS.Element

extension Element: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case enginePath
    case role
    case key
  }

  /// Initialize element from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The vault configuration for default values.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    var enginePath = try container.decodeIfPresent(String.self, forKey: .enginePath)
    if enginePath == .none { enginePath = configuration.defaultEngineConfigurations.aws?.defaultEnginePath }
    guard let enginePath else {
      throw DecodingError.keyNotFound(
        CodingKeys.enginePath,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "The 'enginePath' key is missing and no default value was provided"
        )
      )
    }
    self.enginePath = enginePath
    self.role = try container.decode(String.self, forKey: .role)
    self.key = try container.decode(String.self, forKey: .key)
  }
}

extension Element: Equatable {}
extension Element: Sendable {}
extension Element: Hashable {}
