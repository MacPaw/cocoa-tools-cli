import Foundation
import Testing

@testable import HashiCorpVaultReader

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("KeyValue API Tests")
struct KeyValueAPI {
  @Test
  func test_decodeGetSecretsResult_v1() throws {
    let data: Data = try #require(
      """
      {
        "data": {
          "foo": "bar",
          "ttl": 3600
        }
      }
      """
      .data(using: .utf8)
    )
    let sut: HashiCorpVaultReader.Engine.KeyValue.API = HashiCorpVaultReader.Engine.KeyValue.API()

    let item = HashiCorpVaultReader.Engine.KeyValue.Item(engineVersion: .v1, secretMountPath: "", path: "", version: 0)

    // WHEN
    let secrets = try sut.secretsFromResponse(data, for: item)

    // THEN
    #expect(secrets.mapValues(String.init(describing:)) == ["foo": "bar", "ttl": "3600"])
  }

  @Test
  func test_decodeGetSecretsResult_v2() throws {
    let data: Data = try #require(
      """
      {
        "data": {
          "data": {
            "foo": "bar",
            "ttl": 3600
          }
        }
      }
      """
      .data(using: .utf8)
    )
    let sut: HashiCorpVaultReader.Engine.KeyValue.API = HashiCorpVaultReader.Engine.KeyValue.API()

    let item = HashiCorpVaultReader.Engine.KeyValue.Item(engineVersion: .v2, secretMountPath: "", path: "", version: 0)

    // WHEN
    let secrets = try sut.secretsFromResponse(data, for: item)

    // THEN
    #expect(secrets.mapValues(String.init(describing:)) == ["foo": "bar", "ttl": "3600"])
  }
}
