import Foundation
import SecretsInterface

extension ImportSecrets.Providers.OnePassword {
  /// Represents a specific secret source within 1Password.
  ///
  /// This defines the vault, item, and field label needed to locate a secret.
  public struct Source {
    /// The unique 1Password item.
    public var item: Item

    /// The field labels within the item that contains the secret values.
    public var labels: [String]

    /// A map of fetched secret key labels to a new ones.
    public var labelsMap: [String: String]

    /// Creates a new 1Password source.
    /// - Parameters:
    ///   - item: The unique 1Password item.
    ///   - labels: The field labels within the item that contains the secret values.
    ///   - labelsMap: A map of fetched secret key labels to a new ones.
    public init(item: Item, labels: [String], labelsMap: [String: String]) {
      self.item = item
      self.labels = labels
      self.labelsMap = labelsMap
    }
  }
}

private typealias Source = ImportSecrets.Providers.OnePassword.Source

extension Source {
  /// A unique 1Password item.
  public struct Item {
    /// The account shorthand, sign-in address, account ID, or user ID.
    public var account: String?
    /// The vault name or ID.
    ///
    /// If nil, searches all accessible vaults.
    public var vault: String

    /// The item name or ID containing the secret.
    public var item: String
  }
}
extension Source.Item: Sendable {}
extension Source.Item: Equatable {}
extension Source.Item: Hashable {}
extension Source.Item: SecretSourceItemProtocol {}

extension Source.Item: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case account
    case vault
    case item
  }

  /// Initialize element from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The configuration for default values.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder, configuration: ImportSecrets.Providers.OnePassword.Source.Configuration) throws
  {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let account: String? = try container.decodeIfPresent(key: .account) ?? configuration.account
    let vault: String = try container.decode(key: .vault, or: configuration.vault)
    let item = try container.decode(String.self, forKey: .item)

    self.init(account: account, vault: vault, item: item)
  }
}

extension Source {
  enum Error: Swift.Error { case itemDoestMatch }
  mutating func merge(with other: Self?) throws {
    guard let other else { return }
    guard self.item == other.item else { throw Error.itemDoestMatch }
    guard !self.labels.isEmpty else { return }
    if other.labels.isEmpty {
      self.labels.removeAll()
    }
    else {
      self.labels.append(contentsOf: other.labels)
    }
  }

  func merging(with other: Self?) throws -> Self {
    var result = self
    try result.merge(with: other)
    return result
  }
}

extension Source: Equatable {}
extension Source: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case labels
    case labelsMap
  }

  /// Initialize element from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The configuration for default values.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder, configuration: ImportSecrets.Providers.OnePassword.Source.Configuration) throws
  {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let item = try Item(from: decoder, configuration: configuration)
    let labels: [String] = try container.decodeIfPresent(key: .labels) ?? []
    let labelsMap: [String: String] = try container.decodeIfPresent(key: .labelsMap) ?? [:]

    self.init(item: item, labels: labels, labelsMap: labelsMap)
  }
}
extension Source: Sendable {}

extension Source: SecretSourceProtocol {
  /// Configuration key used to identify this provider in YAML.
  public static let configurationKey: String = "op"

  /// A list of keys to fetch from the secret source item.
  @inlinable
  @inline(__always)
  public var keys: [String] { labels }

  /// A map of fetched secret key labels to a new ones.
  @inlinable
  @inline(__always)
  public var keysMap: [String: String] { labelsMap }
}
