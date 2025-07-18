import ArgumentParser
import EnvSubst

extension EnvSubstCommand {
  /// Command-line options for controlling environment variable substitution behavior.
  ///
  /// These options determine how the substitution process handles unset variables,
  /// empty variables, and error conditions during processing.
  public struct Options: ParsableArguments, Decodable {
    /// When enabled, causes substitution to fail if a referenced variable is not set in the environment.
    /// By default, unset variables are replaced with empty strings.
    @Flag(name: .long, help: "Fail if a variable is not set")
    public var noUnset: Bool = false

    /// When enabled, causes substitution to fail if a referenced variable is set but contains an empty value.
    /// By default, empty variables are allowed and their empty values are used.
    @Flag(name: .long, help: "Fail if a variable is set but empty")
    public var noEmpty: Bool = false

    /// When enabled, stops processing at the first error encountered during substitution.
    /// By default, processing continues and errors are collected for reporting at the end.
    @Flag(name: .long, help: "Fail at first occurrence of an error")
    var failFast: Bool = false

    /// Creates a new Options instance with default values.
    /// All flags are initially set to false, providing the most permissive behavior.
    public init() {}
  }
}

extension EnvSubstCommand.Options {
  /// Converts command-line options to EnvSubst.Options for use with the substitution engine.
  ///
  /// - Returns: An EnvSubst.Options instance configured with the current flag values.
  public var options: EnvSubst.Options { .init(noUnset: noUnset, noEmpty: noEmpty, failFast: failFast) }
}
