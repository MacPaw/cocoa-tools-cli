extension Dictionary where Value: SecretSourceProtocol, Key == String {
  @inlinable
  @inline(__always)
  package var itemsToFetch: [Value.Item: Set<String>] { values.itemsToFetch }
}
