//
//  File.swift
//  cocoa-tools
//
//  Created by Vitalii Budnik on 9/8/25.
//

import Foundation

public protocol HashicorpVaultEngineAPIProtocol: Equatable, Hashable, Sendable {
  associatedtype Element
  func adaptURLRequest(urlRequest: URLRequest, for element: Element) throws -> URLRequest

  func decodeGetSecretsResult(data: Data) throws -> [String: String]
}
