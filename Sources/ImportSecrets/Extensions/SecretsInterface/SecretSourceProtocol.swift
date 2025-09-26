import SecretsInterface

extension SecretSourceProtocol {
  mutating func validate(with sourceConfigurations: ImportSecrets.SourceConfigurations) throws {
    let configuration: Configuration? = try sourceConfigurations.getConfiguration(for: Self.configurationKey)

    try validate(with: configuration)
  }
}
