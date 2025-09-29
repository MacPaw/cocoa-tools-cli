//
//  File.swift
//  cocoa-tools
//
//  Created by Vitalii Budnik on 9/8/25.
//

import Foundation

extension HashiCorpVaultReader.Engine.KeyValue {
  /// Default configuration for KeyValue engine.
  public struct DefaultConfiguration {
    /// The default Key Value engine version.
    public var defaultEngineVersion: EngineVersion
    /// The default secret mount path.
    public var defaultSecretMountPath: String

    /// Initialize default configuration.
    ///
    /// - Parameters:
    ///   - defaultEngineVersion: The default Key Value engine version (defaults to `v2`).
    ///   - defaultSecretMountPath: The default secret mount path (defaults to `secret`).
    public init(defaultEngineVersion: EngineVersion = .default, defaultSecretMountPath: String = "secret") {
      self.defaultSecretMountPath = defaultSecretMountPath
      self.defaultEngineVersion = defaultEngineVersion
    }
  }
}

private typealias DefaultConfiguration = HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration

extension DefaultConfiguration: Decodable {
  private enum CodingKeys: String, CodingKey {
    case defaultEngineVersion
    case defaultSecretMountPath
  }

  /// Initialize from decoder.
  ///
  /// - Parameter decoder: The decoder to read data from.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaultEngineVersion =
      try container.decodeIfPresent(
        HashiCorpVaultReader.Engine.KeyValue.EngineVersion.self,
        forKey: .defaultEngineVersion
      ) ?? .default
    let defaultSecretMountPath = try container.decodeIfPresent(String.self, forKey: .defaultSecretMountPath) ?? "secret"

    self.init(defaultEngineVersion: defaultEngineVersion, defaultSecretMountPath: defaultSecretMountPath)
  }
}

extension DefaultConfiguration: Equatable {}
extension DefaultConfiguration: Sendable {}
extension DefaultConfiguration: HashiCorpVaultEngineDefaultConfigurationProtocol {}
