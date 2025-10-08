import Foundation

extension HashiCorpVaultReader {
  /// Represents a vault element that can be either KeyValue or AWS engine type.
  public struct Element {
    /// Engine item configuration for this element.
    public var item: HashiCorpVaultReader.Element.Item
    /// Keys within the secret to retrieve.
    public var keys: [String]

    /// Initialize a new vault element.
    ///
    /// - Parameters:
    ///   - item: A unique Element item.
    ///   - keys: A list of key to fetch. Optional. Default value is empty list.
    public init(item: Item, keys: [String] = []) {
      self.item = item
      self.keys = keys
    }
  }
}

private typealias Element = HashiCorpVaultReader.Element

extension Element: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey { case keys }
  /// Initialize element from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The vault configuration for default values.
  /// - Throws: DecodingError if decoding fails or validation fails.
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let keys: [String] = try container.decodeIfPresent([String].self, forKey: .keys) ?? []

    let item: HashiCorpVaultReader.Element.Item = try HashiCorpVaultReader.Element.Item(
      from: decoder,
      configuration: configuration
    )

    self.init(item: item, keys: keys)
  }
}

extension Element: Sendable {}
extension Element: Equatable {}
extension Element: Hashable {}
