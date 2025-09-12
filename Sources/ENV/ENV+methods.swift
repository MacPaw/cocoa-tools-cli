extension ENV {
  /// The keys of the environment variables.
  ///
  /// - Returns: A view of the keys.
  @inlinable
  public var keys: Collection.Keys { variables.keys }

  /// The values of the environment variables.
  ///
  /// - Returns: A view of the values.
  @inlinable
  public var values: Collection.Values { variables.values }

  /// Check if a key exists in the environment.
  ///
  /// - Parameter key: The key to check.
  /// - Returns: `true` if the key exists, `false` otherwise.
  @inlinable
  public func hasKey(_ key: Key) -> Bool { keys.contains(key) }

  /// Check if a value exists in the environment.
  ///
  /// - Parameter value: The value to check.
  /// - Returns: `true` if the value exists, `false` otherwise.
  @inlinable
  public func hasValue(_ value: Value) -> Bool { values.contains(value) }

  /// Find the first key for a given value.
  ///
  /// - Parameter value: The value to search for.
  /// - Returns: The first key that maps to the value, or `nil` if not found.
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

  /// Keep only elements that satisfy the given predicate.
  ///
  /// - Parameter isIncluded: A closure that returns `true` for elements to keep.
  @inlinable
  mutating public func keep(_ isIncluded: (Element) throws -> Bool) rethrows {
    variables = try variables.filter(isIncluded)
  }

  /// Return a new ENV keeping only elements that satisfy the given predicate.
  ///
  /// - Parameter isIncluded: A closure that returns `true` for elements to keep.
  /// - Returns: A new ENV with filtered elements.
  @inlinable
  public func keeping(_ isIncluded: (Element) throws -> Bool) rethrows -> Self { try new { try $0.keep(isIncluded) } }

  /// Delete elements that satisfy the given predicate.
  ///
  /// - Parameter isExcluded: A closure that returns `true` for elements to delete.
  @inlinable
  mutating public func delete(_ isExcluded: (Element) throws -> Bool) rethrows {
    variables = try variables.filter { try !isExcluded($0) }
  }

  /// Return a new ENV with elements deleted that satisfy the given predicate.
  ///
  /// - Parameter isExcluded: A closure that returns `true` for elements to delete.
  /// - Returns: A new ENV with filtered elements.
  @inlinable
  public func deleting(_ isExcluded: (Element) throws -> Bool) rethrows -> Self {
    try new { try $0.delete(isExcluded) }
  }

  /// Replace all environment variables with the given collection.
  ///
  /// - Parameter other: The collection to replace with.
  @inlinable
  mutating public func replace(_ other: Collection) { variables = other }

  /// Return a new ENV with all variables replaced by the given collection.
  ///
  /// - Parameter other: The collection to replace with.
  /// - Returns: A new ENV with replaced variables.
  @inlinable
  public func replacing(_ other: Collection) -> Self { new { $0.replace(other) } }

  /// Merge another collection into this ENV.
  ///
  /// - Parameters:
  ///   - other: The collection to merge.
  ///   - combine: A closure that returns the value to use for duplicate keys.
  @inlinable
  mutating public func merge(
    _ other: Collection,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows { try variables.merge(other, uniquingKeysWith: combine) }

  /// Return a new ENV by merging another collection.
  ///
  /// - Parameters:
  ///   - other: The collection to merge.
  ///   - combine: A closure that returns the value to use for duplicate keys.
  /// - Returns: A new ENV with merged variables.
  @inlinable
  public func merging(
    _ other: Collection,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try new { try $0.merging(other, uniquingKeysWith: combine) } }

  /// Replace all environment variables with another ENV.
  ///
  /// - Parameter other: The ENV to replace with.
  @inlinable
  mutating public func replace(_ other: Self) { replace(other.variables) }

  /// Return a new ENV with all variables replaced by another ENV.
  ///
  /// - Parameter other: The ENV to replace with.
  /// - Returns: A new ENV with replaced variables.
  @inlinable
  public func replacing(_ other: Self) -> Self { new { $0.replace(other) } }

  /// Merge another ENV into this ENV.
  ///
  /// - Parameters:
  ///   - other: The ENV to merge.
  ///   - combine: A closure that returns the value to use for duplicate keys.
  @inlinable
  mutating public func merge(
    _ other: Self,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows { try merge(other.variables, uniquingKeysWith: combine) }

  /// Return a new ENV by merging another ENV.
  ///
  /// - Parameters:
  ///   - other: The ENV to merge.
  ///   - combine: A closure that returns the value to use for duplicate keys.
  /// - Returns: A new ENV with merged variables.
  @inlinable
  public func merging(
    _ other: Self,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try new { try $0.merging(other, uniquingKeysWith: combine) } }

  /// Remove all environment variables.
  @inlinable
  mutating public func removeAll() { variables.removeAll() }

  /// Return a new ENV with all variables removed.
  ///
  /// - Returns: A new empty ENV.
  @inlinable
  public func removingAll() -> Self { new { $0.removeAll() } }

  /// Remove the value for a given key.
  ///
  /// - Parameter key: The key to remove.
  /// - Returns: The removed value, or `nil` if the key was not present.
  @inlinable
  mutating public func removeValue(forKey key: Key) -> Value? { variables.removeValue(forKey: key) }

  /// Return a new ENV with the value for a given key removed.
  ///
  /// - Parameter key: The key to remove.
  /// - Returns: A new ENV with the key-value pair removed.
  @inlinable
  public func removingValue(forKey key: Key) -> Self { new { $0.removeValue(forKey: key) } }

  /// Update the value for a given key.
  ///
  /// - Parameters:
  ///   - value: The new value.
  ///   - key: The key to update.
  /// - Returns: The previous value for the key, or `nil` if the key was not present.
  @inlinable
  mutating public func updateValue(_ value: Value, forKey key: Key) -> Value? {
    variables.updateValue(value, forKey: key)
  }

  /// Return a new ENV with the value for a given key updated.
  ///
  /// - Parameters:
  ///   - value: The new value.
  ///   - key: The key to update.
  /// - Returns: A new ENV with the updated key-value pair.
  @inlinable
  public func updatingValue(_ value: Value, forKey key: Key) -> Self { new { $0.updateValue(value, forKey: key) } }
}

extension ENV {
  /// The keys of the current environment variables.
  ///
  /// - Returns: A view of the keys.
  @inlinable
  public static var keys: Collection.Keys { current.keys }

  /// The values of the current environment variables.
  ///
  /// - Returns: A view of the values.
  @inlinable
  public static var values: Collection.Values { current.values }

  /// Check if a key exists in the current environment.
  ///
  /// - Parameter key: The key to check.
  /// - Returns: `true` if the key exists, `false` otherwise.
  @inlinable
  public static func hasKey(_ key: Key) -> Bool { current.hasKey(key) }

  /// Check if a value exists in the current environment.
  ///
  /// - Parameter value: The value to check.
  /// - Returns: `true` if the value exists, `false` otherwise.
  @inlinable
  public static func hasValue(_ value: Value) -> Bool { current.hasValue(value) }

  /// Find the first key for a given value in the current environment.
  ///
  /// - Parameter value: The value to search for.
  /// - Returns: The first key that maps to the value, or `nil` if not found.
  @inlinable
  public static func key(for value: Value) -> Key? { current.key(for: value) }

  /// Return a new ENV from current keeping only elements that satisfy the given predicate.
  ///
  /// - Parameter isIncluded: A closure that returns `true` for elements to keep.
  /// - Returns: A new ENV with filtered elements.
  @inlinable
  public static func keeping(_ isIncluded: (Element) throws -> Bool) rethrows -> Self {
    try current.keeping(isIncluded)
  }

  /// Return a new ENV from current with elements deleted that satisfy the given predicate.
  ///
  /// - Parameter isExcluded: A closure that returns `true` for elements to delete.
  /// - Returns: A new ENV with filtered elements.
  @inlinable
  public static func deleting(_ isExcluded: (Element) throws -> Bool) rethrows -> Self {
    try current.deleting(isExcluded)
  }

  /// Return a new ENV with current variables replaced by the given collection.
  ///
  /// - Parameter other: The collection to replace with.
  /// - Returns: A new ENV with replaced variables.
  @inlinable
  public static func replacing(_ other: Collection) -> Self { current.replacing(other) }

  /// Return a new ENV by merging current with another collection.
  ///
  /// - Parameters:
  ///   - other: The collection to merge.
  ///   - combine: A closure that returns the value to use for duplicate keys.
  /// - Returns: A new ENV with merged variables.
  @inlinable
  public static func merging(
    _ other: Collection,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try current.merging(other, uniquingKeysWith: combine) }

  /// Return a new ENV with current variables replaced by another ENV.
  ///
  /// - Parameter other: The ENV to replace with.
  /// - Returns: A new ENV with replaced variables.
  @inlinable
  public static func replacing(_ other: Self) -> Self { current.replacing(other) }

  /// Return a new ENV by merging current with another ENV.
  ///
  /// - Parameters:
  ///   - other: The ENV to merge.
  ///   - combine: A closure that returns the value to use for duplicate keys.
  /// - Returns: A new ENV with merged variables.
  @inlinable
  public static func merging(
    _ other: Self,
    uniquingKeysWith combine: (Value, Value) throws -> Value = { current, _ in current }
  ) rethrows -> Self { try current.merging(other, uniquingKeysWith: combine) }

  /// Return a new ENV with all current variables removed.
  ///
  /// - Returns: A new empty ENV.
  @inlinable
  public static func removingAll() -> Self { current.removingAll() }

  /// Return a new ENV with the value for a given key removed from current.
  ///
  /// - Parameter key: The key to remove.
  /// - Returns: A new ENV with the key-value pair removed.
  @inlinable
  public static func removingValue(forKey key: Key) -> Self { current.removingValue(forKey: key) }

  /// Return a new ENV with the value for a given key updated from current.
  ///
  /// - Parameters:
  ///   - value: The new value.
  ///   - key: The key to update.
  /// - Returns: A new ENV with the updated key-value pair.
  @inlinable
  public static func updatingValue(_ value: Value, forKey key: Key) -> Self {
    current.updatingValue(value, forKey: key)
  }
}
