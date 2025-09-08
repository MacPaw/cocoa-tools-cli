//
//  File.swift
//  cocoa-tools
//
//  Created by Vitalii Budnik on 9/8/25.
//

import Foundation

extension HashiCorpVaultReader.Engine.KeyValue {
  public struct Element {
    /// The path to the KV mount to config, such as `secret`.
    ///
    /// Defaults to `secret`.
    public var secretMountPath: String
    /// Specifies the path of the secret to read.
    public var path: String
    /// Specifies the version to return.
    ///
    /// If not set or the value is not positive integer (`<= 0`), the latest version is returned.
    public var version: Int
    public var key: String
  }
}

private typealias Element = HashiCorpVaultReader.Engine.KeyValue.Element

extension Element: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case secretMountPath
    case path
    case key
    case version
  }

  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    var secretMountPath = try container.decodeIfPresent(String.self, forKey: .secretMountPath)
    if secretMountPath == .none {
      secretMountPath = configuration.defaultEngineConfigurations.keyValue?.defaultSecretMountPath
    }

    guard let secretMountPath else {
      throw DecodingError.keyNotFound(
        CodingKeys.secretMountPath,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "The 'secretMountPath' key is missing and no default value was provided"
        )
      )
    }

    self.secretMountPath = secretMountPath
    self.path = try container.decode(String.self, forKey: .path)
    self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
    self.key = try container.decode(String.self, forKey: .key)
  }
}

extension Element: Equatable {}
extension Element: Sendable {}
