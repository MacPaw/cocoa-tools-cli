extension Shell {
  // An error type that is presented to the user as an error with parsing their
  /// command-line input.
  public struct Error: Swift.Error, CustomStringConvertible {
    /// The error message represented by this instance, this string is presented to
    /// the user when a `ValidationError` is thrown from either; `run()`,
    /// `validate()` or a transform closure.
    public internal(set) var message: String

    /// Creates a new validation error with the given message.
    ///
    /// - Parameter:
    ///   - message: The error message to be presented to the user.
    ///
    /// - Returns: A new `GenericError` instance with the given message.
    public init(_ message: String) { self.message = message }

    /// An error message.
    public var description: String { message }
  }
}
