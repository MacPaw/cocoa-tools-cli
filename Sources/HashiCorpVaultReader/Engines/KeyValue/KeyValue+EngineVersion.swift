extension HashiCorpVaultReader.Engine.KeyValue {
  /// Key Value secrets engine verion.
  public enum EngineVersion: Int {
    /// Version 1 of the Key Value secrets engine.
    ///
    /// [Key Value v1 docs](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v1).
    case v1 = 1
    /// Version 1 of the Key Value secrets engine.
    ///
    /// [Key Value v2 docs](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2).
    case v2 = 2
  }
}

private typealias EngineVersion = HashiCorpVaultReader.Engine.KeyValue.EngineVersion

extension EngineVersion {
  /// Default Key Value engine version (`v2`).
  @inlinable
  @inline(__always)
  public static var `default`: Self { .v2 }
}

extension EngineVersion: Comparable {
  /// Returns a Boolean value indicating whether the value of the first
  /// argument is less than that of the second argument.
  ///
  /// This function is the only requirement of the `Comparable` protocol. The
  /// remainder of the relational operator functions are implemented by the
  /// standard library for any type that conforms to `Comparable`.
  ///
  /// - Parameters:
  ///   - lhs: A value to compare.
  ///   - rhs: Another value to compare.
  ///
  /// - Returns: `true` if lhs is less than rhs.
  public static func < (
    lhs: HashiCorpVaultReader.Engine.KeyValue.EngineVersion,
    rhs: HashiCorpVaultReader.Engine.KeyValue.EngineVersion
  ) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension EngineVersion: Decodable {}
extension EngineVersion: Equatable {}
extension EngineVersion: Hashable {}
extension EngineVersion: Sendable {}
