import Foundation

extension HashiCorpVaultReader.Element {
  /// A unique Vault item.
  public enum Item {
    case keyValue(HashiCorpVaultReader.Engine.KeyValue.Element)
    case aws(HashiCorpVaultReader.Engine.AWS.Element)
  }
}

extension HashiCorpVaultReader.Element.Item: Sendable {}
extension HashiCorpVaultReader.Element.Item: Equatable {}
extension HashiCorpVaultReader.Element.Item: Hashable {}
extension HashiCorpVaultReader.Element.Item: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case keyValue
    case aws
  }

  /// Initialize a unique element item from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The vault configuration for default values.
  /// - Throws: DecodingError if decoding fails or validation fails.
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let keyValue = try container.decodeIfPresent(
      HashiCorpVaultReader.Engine.KeyValue.Element.self,
      forKey: .keyValue,
      configuration: configuration
    )

    let aws = try container.decodeIfPresent(
      HashiCorpVaultReader.Engine.AWS.Element.self,
      forKey: .aws,
      configuration: configuration
    )

    let engineConfigs: [Any?] = [keyValue, aws]
    guard !engineConfigs.compactMap(\.self).isEmpty else {
      throw DecodingError.valueNotFound(
        Self.self,
        .init(codingPath: decoder.codingPath, debugDescription: "No engine configured for this item.")
      )
    }
    guard engineConfigs.compactMap(\.self).count == 1 else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Too many engine configs. Only one engine can be configured per item (kv or aws, not both)."
        )
      )
    }

    if let keyValue = keyValue {
      self = .keyValue(keyValue)
    }
    else if let aws = aws {
      self = .aws(aws)
    }
    else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Vault configuration is malformed and has no keyValue or aws configuration."
        )
      )
    }
  }
}
