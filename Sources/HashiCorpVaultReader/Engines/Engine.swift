extension HashiCorpVaultReader {
  /// Available HashiCorp Vault engines.
  public enum Engine: String {
    /// Key-Value secrets engine.
    case keyValue
    /// AWS secrets engine.
    case aws
  }
}
