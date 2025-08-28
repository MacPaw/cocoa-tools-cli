extension ENV {
  @inlinable
  public var keys: Collection.Keys { variables.keys }

  @inlinable
  public var values: Collection.Values { variables.values }

  @inlinable
  public func hasKey(_ key: Key) -> Bool { keys.contains(key) }

  @inlinable
  public func hasValue(_ value: Value) -> Bool { values.contains(value) }

  @inlinable
  public func key(for value: Value) -> Key? {
    guard let index = values.firstIndex(of: value) else { return .none }
    return keys[index]
  }

  @inline(__always)
  @usableFromInline
  func new<T>(_ modify: (inout Self) throws -> T) rethrows -> Self {
    var new = self
    _ = try modify(&new)
    return new
  }

  @inlinable
  mutating public func keep(_ isIncluded: (Element) throws -> Bool) rethrows {
    variables = try variables.filter(isIncluded)
  }

  @inlinable
  public func keeping(_ isIncluded: (Element) throws -> Bool) rethrows -> Self { try new { try $0.keep(isIncluded) } }

  @inlinable
  mutating public func delete(_ isExcluded: (Element) throws -> Bool) rethrows {
    variables = try variables.filter { try !isExcluded($0) }
  }

  @inlinable
  public func deleting(_ isExcluded: (Element) throws -> Bool) rethrows -> Self {
    try new { try $0.delete(isExcluded) }
  }

  @inlinable
  mutating public func replace(_ other: Collection) { variables = other }

  @inlinable
  public func replacing(_ other: Collection) -> Self { new { $0.replace(other) } }

  @inlinable
  mutating public func merge(
    _ other: Collection,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows { try variables.merge(other, uniquingKeysWith: combine) }

  @inlinable
  public func merging(
    _ other: Collection,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try new { try $0.merging(other, uniquingKeysWith: combine) } }

  @inlinable
  mutating public func replace(_ other: Self) { replace(other.variables) }

  @inlinable
  public func replacing(_ other: Self) -> Self { new { $0.replace(other) } }

  @inlinable
  mutating public func merge(
    _ other: Self,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows { try merge(other.variables, uniquingKeysWith: combine) }

  @inlinable
  public func merging(
    _ other: Self,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try new { try $0.merging(other, uniquingKeysWith: combine) } }

  @inlinable
  mutating public func removeAll() { variables.removeAll() }

  @inlinable
  public func removingAll() -> Self { new { $0.removeAll() } }

  @inlinable
  mutating public func removeValue(forKey key: Key) -> Value? { variables.removeValue(forKey: key) }

  @inlinable
  public func removingValue(forKey key: Key) -> Self { new { $0.removeValue(forKey: key) } }

  @inlinable
  mutating public func updateValue(_ value: Value, forKey key: Key) -> Value? {
    variables.updateValue(value, forKey: key)
  }

  @inlinable
  public func updatingValue(_ value: Value, forKey key: Key) -> Self { new { $0.updateValue(value, forKey: key) } }
}

extension ENV {
  @inlinable
  public static var keys: Collection.Keys { current.keys }

  @inlinable
  public static var values: Collection.Values { current.values }

  @inlinable
  public static func hasKey(_ key: Key) -> Bool { current.hasKey(key) }

  @inlinable
  public static func hasValue(_ value: Value) -> Bool { current.hasValue(value) }

  @inlinable
  public static func key(for value: Value) -> Key? { current.key(for: value) }

  @inlinable
  public static func keeping(_ isIncluded: (Element) throws -> Bool) rethrows -> Self {
    try current.keeping(isIncluded)
  }

  @inlinable
  public static func deleting(_ isExcluded: (Element) throws -> Bool) rethrows -> Self {
    try current.deleting(isExcluded)
  }

  @inlinable
  public static func replacing(_ other: Collection) -> Self { current.replacing(other) }

  @inlinable
  public static func merging(
    _ other: Collection,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try current.merging(other, uniquingKeysWith: combine) }

  @inlinable
  public static func replacing(_ other: Self) -> Self { current.replacing(other) }

  @inlinable
  public static func merging(
    _ other: Self,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try current.merging(other, uniquingKeysWith: combine) }

  @inlinable
  public static func removingAll() -> Self { current.removingAll() }

  @inlinable
  public static func removingValue(forKey key: Key) -> Self { current.removingValue(forKey: key) }

  @inlinable
  public static func updatingValue(_ value: Value, forKey key: Key) -> Self {
    current.updatingValue(value, forKey: key)
  }
}
