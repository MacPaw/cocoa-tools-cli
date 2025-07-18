import Foundation

extension Dictionary where Key == String, Value == String {
  /// Converts the dictionary to environment variable format strings.
  /// - Parameters:
  ///   - wrappingValues: Whether to wrap values in quotes. Defaults to true.
  ///   - wrapper: The character(s) to use for wrapping values. Defaults to single quote.
  /// - Returns: Array of strings in "KEY=VALUE" format, sorted by key.
  func toEnv(wrappingValues: Bool = true, wrapper: String = "'") -> [String] {
    keys.sorted()
      .map { key in
        let index = self.keys.firstIndex(of: key)!
        let value = self.values[index]
        return "\(key)=\(wrappingValues ? "\(wrapper)\(value)\(wrapper)" : value)"
      }
  }
}
