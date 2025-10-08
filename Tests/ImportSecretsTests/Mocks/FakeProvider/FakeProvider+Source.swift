import ImportSecrets
import SecretsInterface

extension ImportSecrets.Providers.FakeProvider.Source {
  final class Item: Decodable {
    let path: String

    init(path: String) { self.path = path }
  }
}

extension ImportSecrets.Providers.FakeProvider.Source.Item: SecretSourceItemProtocol {
  static func == (
    lhs: ImportSecrets.Providers.FakeProvider.Source.Item,
    rhs: ImportSecrets.Providers.FakeProvider.Source.Item
  ) -> Bool { lhs.path == rhs.path }

  func hash(into hasher: inout Hasher) { hasher.combine(path) }
}

extension ImportSecrets.Providers.FakeProvider {
  final class Source {
    var path: String { item.path }
    let keys: [String]
    let keysMap: [String: String]
    let item: Item

    init(item: Item, keys: [String], keysMap: [String: String]) {
      self.item = item
      self.keys = keys
      self.keysMap = keysMap
    }
  }
}

extension ImportSecrets.Providers.FakeProvider.Source {
  convenience init(path: String, keys: [String], keysMap: [String: String]) {
    self.init(item: .init(path: path), keys: keys, keysMap: keysMap)
  }

  convenience init(path: String, key: String, keysMap: [String: String]) {
    self.init(path: path, keys: [key], keysMap: keysMap)
  }

  func validate() throws {}
}

private typealias Source = ImportSecrets.Providers.FakeProvider.Source

extension Source: Decodable {
  enum CodingKeys: String, CodingKey { case keys, keysMap }
  convenience init(from decoder: any Decoder) throws {
    let item: Item = try Item(from: decoder)
    let keys: [String] = try decoder.container(keyedBy: CodingKeys.self).decode([String].self, forKey: .keys)
    let keysMap: [String: String] =
      try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent([String: String].self, forKey: .keysMap) ?? [:]
    self.init(item: item, keys: keys, keysMap: keysMap)
  }
}

extension Source: SecretSourceProtocol {}

extension Source: Equatable {
  static func == (lhs: ImportSecrets.Providers.FakeProvider.Source, rhs: ImportSecrets.Providers.FakeProvider.Source)
    -> Bool
  { lhs.item == rhs.item && lhs.keys == rhs.keys }
}
