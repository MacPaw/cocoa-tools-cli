import Foundation

extension EnvSubst {
  /// Environment variable substitution errors.
  public enum Error: Swift.Error, Sendable, Equatable {
    /// Variable is not set in the environment.
    case unsetVariable(String)
    /// Variable is set but has an empty value.
    case emptyVariable(String)
    /// Invalid substitution expression syntax.
    case invalidExpression(String)
    /// Cannot convert data to string using the specified encoding.
    case cantConvertDataToString(String.Encoding)
    /// Cannot convert string to data using the specified encoding.
    case cantConvertStringToData(String.Encoding)
    /// Unknown error
    case unknown(String)
  }
}

extension EnvSubst.Error: LocalizedError {
  /// Provides a localized description of the error.
  public var errorDescription: String? {
    switch self {
    case .unsetVariable(let name): return "Variable '\(name)' is not set"
    case .emptyVariable(let name): return "Variable '\(name)' is set but empty"
    case .invalidExpression(let expr): return "Invalid expression: '\(expr)'"
    case .cantConvertDataToString(let encoding): return "Can't convert data to string using \(encoding) encoding"
    case .cantConvertStringToData(let encoding): return "Can't convert string to data using \(encoding) encoding"
    case .unknown(let message): return message
    }
  }
}
