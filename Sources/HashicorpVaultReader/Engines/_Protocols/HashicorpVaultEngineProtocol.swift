import Foundation

public protocol HashicorpVaultEngineProtocol {
  associatedtype DefaultConfiguration: HashicorpVaultEngineDefaultConfigurationProtocol
  associatedtype Element
  associatedtype API: HashicorpVaultEngineAPIProtocol where API.Element == Element
  func readSecrets(api: API) async throws -> [String: String]
}

extension HashicorpVaultEngineAPIProtocol {
  func decodeGetSecretsResult<GetSecretsResult: HashicorpVaultEngineGetSecretsResultProtocol>(
    data: Data,
    type: GetSecretsResult.Type
  ) throws -> [String: String] {
    try JSONDecoder().decode(HashicorpVaultReader.SecretsFetchResult<GetSecretsResult>.self, from: data).data.secrets
  }
}
