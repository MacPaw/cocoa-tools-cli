/// CI type.
public struct CIType {
  /// Name of the CI.
  public let name: String
  /// Initialize a CI type.
  ///
  /// - Parameter name: Name of the CI.
  public init(name: String) { self.name = name }
}

extension CIType: Sendable {}
