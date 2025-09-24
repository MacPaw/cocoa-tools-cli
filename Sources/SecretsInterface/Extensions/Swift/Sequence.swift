extension Sequence where Element: SecretSourceProtocol {
  @inlinable
  @inline(__always)
  package var itemsToFetch: [Element.Item: Set<String>] {
    reduce(into: [:]) { accum, source in
      if source.keys.isEmpty {
        accum[source.item] = []
      }
      else if accum[source.item] == nil {
        accum[source.item] = Set(source.keys)
      }
      else if accum[source.item]?.isEmpty == false {
        accum[source.item, default: []].formUnion(source.keys)
      }
      else {  // if accum[source.item] == [] {
        // NO-OP
      }
    }
  }
}
