import ImportSecrets

extension ImportSecrets.Providers.FakeProvider {
  final class Source {
    let path: String
    let key: String

    init(path: String, key: String) {
      self.path = path
      self.key = key
    }

    func validate() throws {}
  }
}

private typealias Source = ImportSecrets.Providers.FakeProvider.Source

extension Source: Decodable {}

extension Source: Equatable {
  static func == (lhs: ImportSecrets.Providers.FakeProvider.Source, rhs: ImportSecrets.Providers.FakeProvider.Source)
    -> Bool
  { lhs.path == rhs.path && lhs.key == rhs.key }
}

extension Source: SecretSourceProtocol {}
