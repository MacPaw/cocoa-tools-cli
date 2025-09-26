import ImportSecrets
import SecretsInterface

extension ImportSecrets.Providers {
  final class FakeProvider: @unchecked Sendable {
    nonisolated(unsafe) var fetcher: Fetcher

    init(fetcher: Fetcher) { self.fetcher = fetcher }
  }
}

private typealias FakeProvider = ImportSecrets.Providers.FakeProvider

extension FakeProvider: SecretProviderProtocol {}
