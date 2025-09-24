import ImportSecrets
import SecretsInterface

extension ImportSecrets.Providers.FakeProvider {
  final class Fetcher: @unchecked Sendable {
    var fetchItemCalls: [(item: Source.Item, keys: Set<String>, configuration: Source.Configuration)] = []
  }
}

private typealias Fetcher = ImportSecrets.Providers.FakeProvider.Fetcher

extension Fetcher: SecretFetcherProtocol {
  typealias Source = ImportSecrets.Providers.FakeProvider.Source

  func initialize(configuration: Source.Configuration) async throws {}

  func fetchItem(_ item: Source.Item, keys: Set<String>, configuration: Source.Configuration) async throws -> [String:
    String]
  {
    fetchItemCalls.append((item: item, keys: keys, configuration: configuration))
    let missingKeyError = keys.filter { $0.hasSuffix("missing") }
      .map { FetchError.failedToFetch(keyMissing: "\(item.path)\($0)") }.first

    if let missingKeyError { throw missingKeyError }

    let result: [String: String] = keys.reduce(into: [:]) { accum, key in
      let value = "\(item.path).\(key)"
      accum[key] = value
    }

    return result
  }
  enum FetchError: Swift.Error { case failedToFetch(keyMissing: String) }
  //  func fetch(
  //    secrets: [String: ImportSecrets.Providers.FakeProvider.Source],
  //    sourceConfiguration: ImportSecrets.Providers.FakeProvider.Source.Configuration?,
  //  ) async throws -> SecretsFetchResult {
  //    fetchSecretsCalls.append((secrets: secrets, sourceConfiguration: sourceConfiguration))
  //    return .init(
  //      fetchedSecrets: secrets.mapValues { "\($0.path).\($0.key)" }.filter { !$0.value.hasSuffix("missing") },
  //      errors: secrets.mapValues { "\($0.path).\($0.key)" }.filter { $0.value.hasSuffix("missing") }
  //        .mapValues { [FetchError.failedToFetch(keyMissing: $0)] },
  //    )
  //  }
}
