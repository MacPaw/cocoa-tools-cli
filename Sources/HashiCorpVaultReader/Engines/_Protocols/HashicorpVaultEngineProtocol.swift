import Foundation

public protocol HashiCorpVaultEngineProtocol {
  associatedtype DefaultConfiguration: HashiCorpVaultEngineDefaultConfigurationProtocol
  associatedtype Element
  associatedtype API: HashiCorpVaultEngineAPIProtocol where API.Element == Element
  func readSecrets(api: API) async throws -> [String: String]
}

extension HashiCorpVaultEngineAPIProtocol {
  func decodeGetSecretsResult<GetSecretsResult: HashiCorpVaultEngineGetSecretsResultProtocol>(
    data: Data,
    type: GetSecretsResult.Type
  ) throws -> [String: String] {
    try JSONDecoder().decode(HashiCorpVaultReader.SecretsFetchResult<GetSecretsResult>.self, from: data).data.secrets
  }
}
