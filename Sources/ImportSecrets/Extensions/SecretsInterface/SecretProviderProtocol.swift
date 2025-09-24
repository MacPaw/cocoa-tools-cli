import SecretsInterface

extension SecretProviderProtocol {
  func fetch(secrets: [ImportSecrets.Secret], sourceConfiguration: (any SecretConfigurationProtocol)?) async throws
    -> SecretsFetchResult
  {
    // Cast the type-erased configuration to our specific configuration type
    let sourceConfiguration: Source.Configuration? = try Self.getSourceConfiguration(sourceConfiguration)

    // Extract the source configurations from each secret for this provider
    // This converts from Secret objects to provider-specific Source objects
    let secretsToFetch: [Source] = try secrets.reduce(into: []) { accum, secret in
      guard let source: Source = try secret.getSource(for: Self.configurationKey) else { return }
      accum.append(source)
    }

    // Delegate to the typed fetch method
    let results: [Source.Item: SecretsFetchResult] = try await self.fetch(
      secrets: secretsToFetch,
      sourceConfiguration: sourceConfiguration
    )

    var result: SecretsFetchResult = .init()

    for secret in secrets {
      guard let source: Source = try secret.getSource(for: Self.configurationKey) else { continue }
      guard let secretFetchResult = results[source.item] else {
        preconditionFailure("Failed to find a result for \(source)")
      }

      var filteredSecrets = secretFetchResult.fetchedSecrets
      if !source.keys.isEmpty { filteredSecrets = filteredSecrets.filter { key, _ in source.keys.contains(key) } }

      var fetchedSecrets: [String: String] = [:]
      if !secret.prefix.isEmpty {
        for (key, value) in filteredSecrets { fetchedSecrets["\(secret.prefix)\(key)"] = value }
      }
      else {
        fetchedSecrets = secretFetchResult.fetchedSecrets
      }

      try result.addFetchedSecrets(fetchedSecrets)
      result.addErrors(secretFetchResult.errors)
    }

    return result
  }
}
