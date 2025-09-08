//
//  File.swift
//  cocoa-tools
//
//  Created by Vitalii Budnik on 9/8/25.
//

import Foundation

extension HashicorpVaultReader.Engine.KeyValue {
  public struct DefaultConfiguration {
    public var defaultSecretMountPath: String

    public init(defaultSecretMountPath: String = "secret") { self.defaultSecretMountPath = defaultSecretMountPath }
  }
}

private typealias DefaultConfiguration = HashicorpVaultReader.Engine.KeyValue.DefaultConfiguration

extension DefaultConfiguration: Decodable {
  private enum CodingKeys: String, CodingKey { case defaultSecretMountPath }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaultSecretMountPath = try container.decodeIfPresent(String.self, forKey: .defaultSecretMountPath) ?? "secret"

    self.init(defaultSecretMountPath: defaultSecretMountPath)
  }
}

extension DefaultConfiguration: Equatable {}
extension DefaultConfiguration: Sendable {}
extension DefaultConfiguration: HashicorpVaultEngineDefaultConfigurationProtocol {}
