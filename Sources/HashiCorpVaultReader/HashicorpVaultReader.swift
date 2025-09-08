import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HashiCorpVaultEngineGetSecretsResultProtocol: Decodable { var secrets: [String: String] { get } }

public protocol HashiCorpVaultReaderProtocol: Sendable {
  func fetch(secrets: [String: HashiCorpVaultReader.Element], configuration: HashiCorpVaultReader.Configuration)
    async throws -> [String: String]
}

public struct HashiCorpVaultReader { public init() {} }

extension HashiCorpVaultReader {
  struct SecretsFetchResult<ContainedData: Decodable>: Decodable { let data: ContainedData }
}

extension HashiCorpVaultReader {
  public struct Element {
    public var keyValue: HashiCorpVaultReader.Engine.KeyValue.Element?
    public var aws: HashiCorpVaultReader.Engine.AWS.Element?

    public init(
      keyValue: HashiCorpVaultReader.Engine.KeyValue.Element? = nil,
      aws: HashiCorpVaultReader.Engine.AWS.Element? = nil
    ) {
      self.keyValue = keyValue
      self.aws = aws
    }
  }
}

extension HashiCorpVaultReader.Element: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case keyValue = "kv"
    case aws
  }
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.keyValue = try container.decodeIfPresent(
      HashiCorpVaultReader.Engine.KeyValue.Element.self,
      forKey: .keyValue,
      configuration: configuration
    )

    self.aws = try container.decodeIfPresent(
      HashiCorpVaultReader.Engine.AWS.Element.self,
      forKey: .aws,
      configuration: configuration
    )
  }
}

extension HashiCorpVaultReader.Element: Sendable {}

extension HashiCorpVaultReader: Sendable {}

extension HashiCorpVaultReader: HashiCorpVaultReaderProtocol {
  public enum HTTPError: Swift.Error {
    case responseNotHTTP(URLResponse)
    case wrongStatusCode(Int)
  }

  func fetch(urlRequest: URLRequest, api: any HashiCorpVaultEngineAPIProtocol) async throws -> [String: String] {
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else { throw HTTPError.wrongStatusCode(response.statusCode) }
    let result = try api.decodeGetSecretsResult(data: data)
    return result
  }

  public func fetch(secrets: [String: Element], configuration: Configuration) async throws -> [String: String] {
    // Group secrets by unique item (vault + item name) to batch field requests
    // This optimization allows us to fetch multiple fields from the same item in one API call
    // instead of making separate calls for each field
    let itemsToFetch: [UniqueItem: Set<String>] = secrets.values.reduce(into: [:]) { accum, source in
      let uniqueItem: UniqueItem = .init(source: source)
      if let path = source.keyValue?.path {
        accum[uniqueItem, default: []].insert(path)
      }
      else if let key = source.aws?.key {
        accum[uniqueItem, default: []].insert(key)
      }
    }

    let keyValueAPI = HashiCorpVaultReader.Engine.KeyValue.API()
    let awsAPI = HashiCorpVaultReader.Engine.AWS.API()

    let baseRequest: URLRequest = try configuration.buildURLRequest()

    let result: [String: String] = try await withThrowingTaskGroup(
      of: [String: String].self,
      returning: [String: String].self
    ) { taskGroup in
      for (item, keys) in itemsToFetch {
        let urlRequest: URLRequest
        let api: any HashiCorpVaultEngineAPIProtocol
        if let keyValue = item.keyValue {
          urlRequest = try keyValueAPI.adaptURLRequest(urlRequest: baseRequest, for: keyValue)
          api = keyValueAPI
        }
        else if let aws = item.aws {
          urlRequest = try awsAPI.adaptURLRequest(urlRequest: baseRequest, for: aws)
          api = awsAPI
        }
        else {
          continue
        }

        taskGroup.addTask { [self, urlRequest, keys] in try await self.fetch(urlRequest: urlRequest, api: api).filter { keys.contains($0.key) } }
      }

      return try await taskGroup.reduce(into: [String: String]()) { partialResult, name in
        partialResult.merge(name, uniquingKeysWith: { lhs, rhs in lhs })
      }
    }

    return result
  }

  /// Represents a unique 1Password item (vault + item name combination).
  ///
  /// Used to group multiple field requests for the same item to optimize API calls.
  fileprivate struct UniqueItem: Equatable, Hashable {
    fileprivate struct KeyValue: Equatable, Hashable, HashiCorpVaultReaderKeyValueUniqueElement {
      var secretMountPath: String
      var path: String
      var version: Int

      init?(source: HashiCorpVaultReader.Engine.KeyValue.Element?) {
        guard let source else { return nil }
        self.secretMountPath = source.secretMountPath
        self.path = source.path
        self.version = 0
      }
    }
    fileprivate struct AWS: Equatable, Hashable, HashiCorpVaultReaderAWSUniqueElement {
      var enginePath: String
      var role: String
      init?(source: HashiCorpVaultReader.Engine.AWS.Element?) {
        guard let source else { return nil }
        self.enginePath = source.enginePath
        self.role = source.role
      }
    }
    var keyValue: KeyValue?
    var aws: AWS?

    /// Creates a UniqueItem from a source, applying default account and vault if needed.
    init(source: HashiCorpVaultReader.Element) {
      keyValue = .init(source: source.keyValue)
      aws = .init(source: source.aws)
    }
  }
}
