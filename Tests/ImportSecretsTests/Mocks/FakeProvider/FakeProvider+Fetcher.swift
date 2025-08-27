import ImportSecrets

extension ImportSecrets.Providers.FakeProvider {
  final class Fetcher: @unchecked Sendable {
    var fetchSecretsCalls:
      [(
        secrets: [String: ImportSecrets.Providers.FakeProvider.Source],
        sourceConfiguration: ImportSecrets.Providers.FakeProvider.Source.Configuration?
      )] = []
  }
}

private typealias Fetcher = ImportSecrets.Providers.FakeProvider.Fetcher

extension Fetcher: SecretFetcherProtocol {
  enum FetchError: Swift.Error { case failedToFetch(keyMissing: String) }
  func fetch(
    secrets: [String: ImportSecrets.Providers.FakeProvider.Source],
    sourceConfiguration: ImportSecrets.Providers.FakeProvider.Source.Configuration?,
  ) async throws -> SecretsFetchResult {
    fetchSecretsCalls.append((secrets: secrets, sourceConfiguration: sourceConfiguration))
    return .init(
      fetchedSecrets: secrets.mapValues { "\($0.path).\($0.key)" }.filter { !$0.value.hasSuffix("missing") },
      errors: secrets.mapValues { "\($0.path).\($0.key)" }.filter { $0.value.hasSuffix("missing") }
        .mapValues { [FetchError.failedToFetch(keyMissing: $0)] },
    )
  }
}
