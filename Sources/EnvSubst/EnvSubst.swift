import Foundation

/// Environment variable substitution utility.
public struct EnvSubst: Sendable {
  private let environment: [String: String]
  private let options: Options

  /// Initialize with environment and options.
  ///
  /// - Parameters:
  ///   - environment: Environment variables.
  ///   - options: Substitution options.
  public init(environment: [String: String] = ProcessInfo.processInfo.environment, options: Options = .default) {
    self.environment = environment
    self.options = options
  }

  /// Substitute environment variables in a string.
  ///
  /// - Parameter input: Input string with variable expressions.
  /// - Returns: String with substituted variables.
  /// - Throws: EnvSubst.Error if substitution fails.
  public func substitute(_ input: String) throws(EnvSubst.Error) -> String {
    let lexer = Lexer(input: input)
    let tokens = lexer.tokenizeWithSubstitutionSupport()

    let parser = Parser(tokens: tokens)
    let nodes = try parser.parse()

    var result = ""
    var errors: [EnvSubst.Error] = []
    var environment = environment

    for node in nodes {
      do { result += try node.evaluate(environment: &environment, options: options) }
      catch let error {
        if options.failFast { throw error }
        errors.append(error)
      }
    }

    if !errors.isEmpty && !options.failFast {
      guard let firstError = errors.first else { throw Error.unknown("Unknown error occurred during substitution") }
      throw firstError
    }

    return result
  }
}

// MARK: - Convenience methods

extension EnvSubst {
  /// Substitute environment variables in a string using provided options.
  ///
  /// - Parameters:
  ///   - input: Input string with variable expressions.
  ///   - environment: Environment variables.
  ///   - options: Substitution options.
  /// - Returns: String with substituted variables.
  /// - Throws: EnvSubst.Error if substitution fails.
  public static func substitute(
    _ input: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    options: Options = .default,
  ) throws(Error) -> String {
    let envsubst: EnvSubst = .init(environment: environment, options: options)
    return try envsubst.substitute(input)
  }

  /// Substitute environment variables in a Data using provided options.
  ///
  /// - Parameters:
  ///   - input: Input Data with variable expressions.
  ///   - environment: Environment variables.
  ///   - options: Substitution options.
  ///   - encoding: String encoding to use for conversion.
  /// - Returns: Data with substituted variables.
  /// - Throws: EnvSubst.Error if substitution fails.
  public static func substitute(
    _ input: Data,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    options: Options = .default,
    encoding: String.Encoding = .utf8,
  ) throws(Error) -> Data {
    guard let string = String(data: input, encoding: encoding) else { throw .cantConvertDataToString(encoding) }
    let substitutedString = try EnvSubst.substitute(string, environment: environment, options: options)
    guard let data = substitutedString.data(using: encoding) else { throw .cantConvertStringToData(encoding) }
    return data
  }
}
