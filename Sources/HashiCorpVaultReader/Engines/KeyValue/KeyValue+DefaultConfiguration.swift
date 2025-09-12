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
    /// The default secret mount path.
    public var defaultSecretMountPath: String

    /// Initialize default configuration.
    ///
    /// - Parameter defaultSecretMountPath: The default secret mount path (defaults to "secret").
    public init(defaultSecretMountPath: String = "secret") { self.defaultSecretMountPath = defaultSecretMountPath }
  }
}

private typealias DefaultConfiguration = HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration

extension DefaultConfiguration: Decodable {
  private enum CodingKeys: String, CodingKey { case defaultSecretMountPath }

  /// Initialize from decoder.
  ///
  /// - Parameter decoder: The decoder to read data from.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaultSecretMountPath = try container.decodeIfPresent(String.self, forKey: .defaultSecretMountPath) ?? "secret"

    self.init(defaultSecretMountPath: defaultSecretMountPath)
  }
}

extension DefaultConfiguration: Equatable {}
extension DefaultConfiguration: Sendable {}
extension DefaultConfiguration: HashiCorpVaultEngineDefaultConfigurationProtocol {}
