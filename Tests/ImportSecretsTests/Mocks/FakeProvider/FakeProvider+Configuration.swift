import Foundation
import ImportSecrets
import SecretsInterface

extension ImportSecrets.Providers.FakeProvider.Source {
  final class Configuration {
    let url: URL?

    init(url: URL?) { self.url = url }
  }
}

private typealias Configuration = ImportSecrets.Providers.FakeProvider.Source.Configuration

extension Configuration: Decodable {}

extension Configuration: Equatable {
  static func == (
    lhs: ImportSecrets.Providers.FakeProvider.Source.Configuration,
    rhs: ImportSecrets.Providers.FakeProvider.Source.Configuration,
  ) -> Bool { lhs.url == rhs.url }
}

extension Configuration: SecretConfigurationProtocol { static let configurationKey: String = "fake-source" }
