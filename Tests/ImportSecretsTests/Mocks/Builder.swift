//
//  File.swift
//  mpct
//
//  Created by Vitalii Budnik on 8/14/25.
//

import Foundation
import SecretsInterface
import Testing

@testable import ImportSecrets

enum MocksBuilder {
  static func configuration(
    sourceConfigurations: ImportSecrets.SourceConfigurations = .init(configurations: [:]),
    secrets: [ImportSecrets.Secret],
    sourceProviders: [any SecretProviderProtocol] = [],
    onePasswordCLI: MockOnePasswordCLI? = .none,
    secretNamesMapping: [String: String] = [:]
  ) throws -> ImportSecrets.Configuration {
    var config = ImportSecrets.Configuration(
      version: .none,
      sourceConfigurations: sourceConfigurations,
      secrets: secrets,
      sourceProviders: sourceProviders,
      secretNamesMapping: secretNamesMapping,
    )

    try config.sourceConfigurations.addConfiguration(
      ImportSecrets.Providers.OnePassword.Source.Configuration(vault: .none)
    )
    try config.sourceConfigurations.addConfiguration(
      ImportSecrets.Providers.HashiCorpVault.Source.Configuration(
        vaultAddress: #require(URL(string: "https://vault.example.com")),
        defaultEngineConfigurations: .init(
          keyValue: .init(defaultSecretMountPath: "secrets"),
          aws: .init(defaultEnginePath: "aws")
        ),
        authenticationCredentials: .init(token: .init(vaultToken: "fake-token")),
        authenticationMethod: .token
      )
    )

    config.sourceProviders.append(onePasswordProvider(onePasswordCLI: onePasswordCLI))
    return config
  }

  static func onePasswordProvider(onePasswordCLI: MockOnePasswordCLI? = nil) -> ImportSecrets.Providers.OnePassword {
    ImportSecrets.Providers.OnePassword(fetcher: onePasswordFetcher(onePasswordCLI: onePasswordCLI))
  }

  static func onePasswordCLIMock() -> MockOnePasswordCLI {
    let mock = MockOnePasswordCLI()
    mock.mockFields = [
      "shared-item": ["item1-secret": "test-item1-secret-value", "item1-multiline": "test-item1\nmultiline-value"],
      "database-item": ["item2-secret": "test-item2-secret-value"],
    ]
    return mock
  }

  static func onePasswordFetcher(onePasswordCLI: MockOnePasswordCLI? = nil)
    -> ImportSecrets.Providers.OnePassword.Fetcher
  { .init(onePasswordCLI: onePasswordCLI ?? onePasswordCLIMock()) }

  static func onePasswordSecret(prefix: String, item: String, label: String) throws -> ImportSecrets.Secret {
    let item = ImportSecrets.Providers.OnePassword.Source.Item.init(vault: "some-vault", item: item)
    let opSecretSource = ImportSecrets.Providers.OnePassword.Source(item: item, labels: [label], labelsMap: [:])
    let secret = try ImportSecrets.Secret(prefix: prefix, sources: [opSecretSource])
    return secret
  }
}
