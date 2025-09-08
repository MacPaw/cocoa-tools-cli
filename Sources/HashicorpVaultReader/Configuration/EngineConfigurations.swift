//
//  File.swift
//  cocoa-tools
//
//  Created by Vitalii Budnik on 9/8/25.
//

import Foundation

extension HashicorpVaultReader.Configuration {
  public struct EngineConfigurations {
    public var keyValue: HashicorpVaultReader.Engine.KeyValue.DefaultConfiguration?
    public var aws: HashicorpVaultReader.Engine.AWS.DefaultConfiguration?

    public init(
      keyValue: HashicorpVaultReader.Engine.KeyValue.DefaultConfiguration? = nil,
      aws: HashicorpVaultReader.Engine.AWS.DefaultConfiguration? = nil
    ) {
      self.keyValue = keyValue
      self.aws = aws
    }

    func configuration(for engine: HashicorpVaultReader.Engine) -> (
      any HashicorpVaultEngineDefaultConfigurationProtocol
    )? {
      switch engine {
      case .keyValue: return keyValue
      case .aws: return aws
      }
    }
  }
}

private typealias EngineConfigurations = HashicorpVaultReader.Configuration.EngineConfigurations

extension EngineConfigurations: Equatable {}
extension EngineConfigurations: Decodable {}
extension EngineConfigurations: Sendable {}
