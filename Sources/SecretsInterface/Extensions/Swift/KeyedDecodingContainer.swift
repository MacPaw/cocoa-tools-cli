extension KeyedDecodingContainer {
  @inline(__always)
  @inlinable
  package func decodeIfPresent<T: Decodable>(key: KeyedDecodingContainer<K>.Key, type: T.Type = T.self) throws -> T? {
    try decodeIfPresent(type, forKey: key)
  }

  @inline(__always)
  @inlinable
  package func decode<T: Decodable>(key: KeyedDecodingContainer<K>.Key, type: T.Type = T.self) throws -> T {
    try decode(type, forKey: key)
  }

  @inline(__always)
  @inlinable
  package func decode<T: Decodable>(key: KeyedDecodingContainer<K>.Key, type: T.Type = T.self, or default: T?) throws
    -> T
  {
    if let `default` {
      try decodeIfPresent(key: key, type: type) ?? `default`
    }
    else {
      try decode(key: key, type: type)
    }
  }
}
