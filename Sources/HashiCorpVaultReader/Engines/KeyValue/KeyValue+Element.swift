//
//  File.swift
//  cocoa-tools
//
//  Created by Vitalii Budnik on 9/8/25.
//

import Foundation
import SecretsInterface

extension HashiCorpVaultReader.Engine.KeyValue {
  /// Element configuration for KeyValue engine operations.
  public struct Element {
    /// The Key Value engine version.
    public var engineVersion: HashiCorpVaultReader.Engine.KeyValue.EngineVersion
    /// The path to the KV mount to config, such as `secret`.
    ///
    /// Defaults to `secret`.
    public var secretMountPath: String
    /// Specifies the path of the secret to read.
    public var path: String
    /// Specifies the secret version to return.
    ///
    /// If not set or the value is not positive integer (`<= 0`), the latest version is returned.
    public var version: Int
  }
}

private typealias Element = HashiCorpVaultReader.Engine.KeyValue.Element

extension Element: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case engineVersion
    case secretMountPath
    case path
    case version
  }

  /// Initialize element from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The vault configuration for default values.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let secretMountPath: String = try container.decode(
      key: .secretMountPath,
      or: configuration.defaultEngineConfigurations.keyValue?.defaultSecretMountPath
    )

    let engineVersion: HashiCorpVaultReader.Engine.KeyValue.EngineVersion = try container.decode(
      key: .engineVersion,
      or: configuration.defaultEngineConfigurations.keyValue?.defaultEngineVersion
    )
    let secretsPath: String = try container.decode(String.self, forKey: .path)
    let version: Int = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
    self.init(engineVersion: engineVersion, secretMountPath: secretMountPath, path: secretsPath, version: version)
  }
}

extension Element: Equatable {}
extension Element: Sendable {}
extension Element: Hashable {}
extension Element: HashiCorpVaultEngineElement {}
