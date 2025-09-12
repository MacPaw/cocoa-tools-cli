extension ENV {
  /// Check equality between ENV and dictionary.
  ///
  /// - Parameters:
  ///   - lhs: Left-hand side ENV instance.
  ///   - rhs: Right-hand side dictionary.
  /// - Returns: `true` if equal, `false` otherwise.
  public static func == (lhs: ENV, rhs: [String: String]) -> Bool { lhs.variables == rhs }

  /// Check equality between dictionary and ENV.
  ///
  /// - Parameters:
  ///   - lhs: Left-hand side dictionary.
  ///   - rhs: Right-hand side ENV instance.
  /// - Returns: `true` if equal, `false` otherwise.
  public static func == (lhs: [String: String], rhs: ENV) -> Bool { lhs == rhs.variables }
}

extension ENV: Decodable {
  /// Initialize from decoder.
  ///
  /// - Parameter decoder: The decoder to read data from.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder) throws {
    let variables = try decoder.singleValueContainer().decode([String: String].self)
    self.init(variables: variables)
  }
}

extension ENV: Encodable {
  /// Encode to encoder.
  ///
  /// - Parameter encoder: The encoder to write data to.
  /// - Throws: EncodingError if encoding fails.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(variables)
  }
}

extension ENV: ExpressibleByDictionaryLiteral {
  /// Key type for dictionary literal.
  public typealias Key = String
  /// Value type for dictionary literal.
  public typealias Value = String

  /// Initialize from dictionary literal.
  ///
  /// - Parameter elements: Key-value pairs.
  public init(dictionaryLiteral elements: (String, String)...) {
    self.init(variables: Dictionary(uniqueKeysWithValues: elements))
  }
}

extension ENV {
  /// Collection type alias for underlying dictionary.
  public typealias Collection = [Key: Value]
}

extension ENV: Sequence {
  /// Element type for sequence iteration.
  public typealias Element = (key: Key, value: Value)
  /// Iterator type for sequence iteration.
  public typealias Iterator = Collection.Iterator

  /// Create an iterator for the sequence.
  ///
  /// - Returns: An iterator over the key-value pairs.
  @inlinable
  public func makeIterator() -> Iterator { variables.makeIterator() }

  /// A value less than or equal to the number of elements in the sequence.
  ///
  /// - Returns: The underestimated count.
  @inlinable
  public var underestimatedCount: Int { variables.underestimatedCount }
}

extension ENV: Collection {
  /// Index type for collection access.
  public typealias Index = Collection.Index
  /// SubSequence type for collection slicing.
  public typealias SubSequence = Slice<Collection>
  /// Indices type for collection indexing.
  public typealias Indices = DefaultIndices<Collection>

  /// The position of the first element in a nonempty dictionary.
  ///
  /// If the collection is empty, `startIndex` is equal to `endIndex`.
  ///
  /// - Complexity: Amortized O(1) if the dictionary does not wrap a bridged
  ///   `NSDictionary`. If the dictionary wraps a bridged `NSDictionary`, the
  ///   performance is unspecified.
  @inlinable
  public var startIndex: Index { variables.startIndex }

  /// The dictionary's "past the end" position---that is, the position one
  /// greater than the last valid subscript argument.
  ///
  /// If the collection is empty, `endIndex` is equal to `startIndex`.
  ///
  /// - Complexity: Amortized O(1) if the dictionary does not wrap a bridged
  ///   `NSDictionary`; otherwise, the performance is unspecified.
  @inlinable
  public var endIndex: Index { variables.endIndex }

  /// Returns the position immediately after the given index.
  ///
  /// The successor of an index must be well defined. For an index `i` into a
  /// collection `c`, calling `c.index(after: i)` returns the same index every
  /// time.
  ///
  /// - Parameter i: A valid index of the collection. `i` must be less than
  ///   `endIndex`.
  /// - Returns: The index value immediately after `i`.
  @inlinable
  public func index(after i: Index) -> Index { variables.index(after: i) }

  /// Replaces the given index with its successor.
  ///
  /// - Parameter i: A valid index of the collection. `i` must be less than
  ///   `endIndex`.
  @inlinable
  public func formIndex(after i: inout Index) { variables.formIndex(after: &i) }

  /// Returns the index for the given key.
  ///
  /// If the given key is found in the dictionary, this method returns an index
  /// into the dictionary that corresponds with the key-value pair.
  ///
  /// - Parameter key: The key to find in the dictionary.
  /// - Returns: The index for `key` and its associated value if `key` is in
  ///   the dictionary; otherwise, `nil`.
  @inlinable
  public func index(forKey key: Key) -> Index? { variables.index(forKey: key) }

  /// The indices that are valid for subscripting the collection, in ascending
  /// order.
  ///
  /// A collection's `indices` property can hold a strong reference to the
  /// collection itself, causing the collection to be nonuniquely referenced.
  /// If you mutate the collection while iterating over its indices, a strong
  /// reference can result in an unexpected copy of the collection. To avoid
  /// the unexpected copy, use the `index(after:)` method starting with
  /// `startIndex` to produce indices instead.
  ///
  ///     var c = MyFancyCollection([10, 20, 30, 40, 50])
  ///     var i = c.startIndex
  ///     while i != c.endIndex {
  ///         c[i] /= 5
  ///         i = c.index(after: i)
  ///     }
  ///     // c == MyFancyCollection([2, 4, 6, 8, 10])
  @inlinable
  public var indices: Indices { variables.indices }

  /// The number of key-value pairs in the dictionary.
  ///
  /// - Complexity: O(1).
  @inlinable
  public var count: Int { variables.count }

  /// A Boolean value that indicates whether the dictionary is empty.
  ///
  /// Dictionaries are empty when created with an initializer or an empty
  /// dictionary literal.
  @inlinable
  public var isEmpty: Bool { variables.isEmpty }

  /// Accesses the key-value pair at the specified position.
  ///
  /// This subscript takes an index into the dictionary, instead of a key, and
  /// returns the corresponding key-value pair as a tuple. When performing
  /// collection-based operations that return an index into a dictionary, use
  /// this subscript with the resulting value.
  ///
  /// - Parameter position: The position of the key-value pair to access.
  ///   `position` must be a valid index of the dictionary and not equal to
  ///   `endIndex`.
  /// - Returns: A two-element tuple with the key and value corresponding to
  ///   `position`.
  /// Access the key-value pair at the specified position.
  ///
  /// - Parameter position: The position to access.
  /// - Returns: The key-value pair at the position.
  @inlinable
  public subscript(position: Index) -> Element { variables[position] }

  /// Access a subsequence within the specified bounds.
  ///
  /// - Parameter bounds: The range of indices.
  /// - Returns: A subsequence within the bounds.
  @inlinable
  public subscript(bounds: Range<Self.Index>) -> Self.SubSequence { variables[bounds] }
}
