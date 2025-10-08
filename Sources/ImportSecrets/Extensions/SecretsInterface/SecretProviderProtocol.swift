import SecretsInterface

extension SecretProviderProtocol {
  fileprivate func sourcesToFetch(from secrets: [ImportSecrets.Secret]) throws -> [Source] {
    try secrets.reduce(into: []) { accum, secret in
      guard let source: Source = try secret.getSource(for: Self.configurationKey) else { return }
      accum.append(source)
    }
  }

  fileprivate func buildResultFrom(
    sourceFetchResults: [Source.Item: SecretsFetchResult],
    for secrets: [ImportSecrets.Secret]
  ) throws -> SecretsFetchResult {
    var result: SecretsFetchResult = .init()

    for secret in secrets {
      guard let source: Source = try secret.getSource(for: Self.configurationKey) else { continue }
      guard let secretFetchResult: SecretsFetchResult = sourceFetchResults[source.item] else {
        preconditionFailure("Failed to find a result for \(source)")
      }

      var filteredSecrets: [String: String] = secretFetchResult.fetchedSecrets
      if !source.keys.isEmpty { filteredSecrets = filteredSecrets.filter { key, _ in source.keys.contains(key) } }

      let newKey: (_ sourceSecretKey: String) -> String = { [secret, source] sourceSecretKey in
        let key: String = source.keysMap[sourceSecretKey] ?? sourceSecretKey
        guard !secret.prefix.isEmpty else { return key }
        return "\(secret.prefix)\(key)"
      }

      var fetchedSecrets: [String: String] = [:]
      for (sourceSecretKey, value) in filteredSecrets { fetchedSecrets[newKey(sourceSecretKey)] = value }

      var fetchErrors: [String: [any Swift.Error]] = [:]
      for (sourceSecretKey, value) in secretFetchResult.errors { fetchErrors[newKey(sourceSecretKey)] = value }

      try result.addFetchedSecrets(fetchedSecrets)
      result.addErrors(fetchErrors)
    }

    return result
  }

  func fetch(secrets: [ImportSecrets.Secret], sourceConfiguration: (any SecretConfigurationProtocol)?) throws
    -> SecretsFetchResult
  {
    // Cast the type-erased configuration to our specific configuration type
    let sourceConfiguration: Source.Configuration? = try Self.getSourceConfiguration(sourceConfiguration)

    // Extract the source configurations from each secret for this provider
    // This converts from Secret objects to provider-specific Source objects
    let sourcesToFetch: [Source] = try sourcesToFetch(from: secrets)

    // Delegate to the typed fetch method
    let results: [Source.Item: SecretsFetchResult] = try self.fetch(
      sources: sourcesToFetch,
      sourceConfiguration: sourceConfiguration
    )

    let result: SecretsFetchResult = try buildResultFrom(sourceFetchResults: results, for: secrets)

    return result
  }
}

extension SecretProviderAsyncProtocol {
  func fetch(secrets: [ImportSecrets.Secret], sourceConfiguration: (any SecretConfigurationProtocol)?) async throws
    -> SecretsFetchResult
  {
    // Cast the type-erased configuration to our specific configuration type
    let sourceConfiguration: Source.Configuration? = try Self.getSourceConfiguration(sourceConfiguration)

    // Extract the source configurations from each secret for this provider
    // This converts from Secret objects to provider-specific Source objects
    let sourcesToFetch: [Source] = try sourcesToFetch(from: secrets)

    // Delegate to the typed fetch method
    let results: [Source.Item: SecretsFetchResult] = try await self.fetch(
      sources: sourcesToFetch,
      sourceConfiguration: sourceConfiguration
    )

    let result: SecretsFetchResult = try buildResultFrom(sourceFetchResults: results, for: secrets)

    return result
  }
}
