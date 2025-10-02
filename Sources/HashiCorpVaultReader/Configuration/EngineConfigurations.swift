//
//  File.swift
//  cocoa-tools
//
//  Created by Vitalii Budnik on 9/8/25.
//

import Foundation

extension HashiCorpVaultReader.Configuration {
  /// Default configurations for vault engines.
  public struct EngineConfigurations {
    /// Default configuration for KeyValue engine.
    public var keyValue: HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration?
    /// Default configuration for AWS engine.
    public var aws: HashiCorpVaultReader.Engine.AWS.DefaultConfiguration?

    /// Initialize engine configurations.
    ///
    /// - Parameters:
    ///   - keyValue: Optional KeyValue engine default configuration.
    ///   - aws: Optional AWS engine default configuration.
    public init(
      keyValue: HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration? = .init(),
      aws: HashiCorpVaultReader.Engine.AWS.DefaultConfiguration? = .init()
    ) {
      self.keyValue = keyValue
      self.aws = aws
    }
  }
}

private typealias EngineConfigurations = HashiCorpVaultReader.Configuration.EngineConfigurations

extension EngineConfigurations: Equatable {}
extension EngineConfigurations: Decodable {}
extension EngineConfigurations: Sendable {}
