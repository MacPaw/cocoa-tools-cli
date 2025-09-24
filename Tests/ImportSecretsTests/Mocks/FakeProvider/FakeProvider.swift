import ImportSecrets
import SecretsInterface

extension ImportSecrets.Providers {
  final class FakeProvider {
    let fetcher: Fetcher

    init(fetcher: Fetcher) { self.fetcher = fetcher }
  }
}

private typealias FakeProvider = ImportSecrets.Providers.FakeProvider

extension FakeProvider: SecretProviderProtocol {}
