@_exported public import SemanticVersion

/// A freestanding macro that parses a semantic version string at compile time.
///
/// Use `SemanticVersion` to embed a semantic version directly into your code as a value.
///
/// The macro parses the string according to the [Semantic Versioning 2.0.0](https://semver.org/) specification.
/// If the string is invalid, a compile-time error will occur.
///
/// # Example
///
/// ```swift
/// let version = #semanticVersion("1.2.3-alpha.1+build.5")
/// ```
///
/// - Parameter string: A string literal representing a semantic version.
/// - Returns: A `SemanticVersion` instance parsed from the given string.
@freestanding(expression)
public macro semanticVersion(_ string: String) -> SemanticVersion =
  #externalMacro(module: "SemanticVersionMacroPlugin", type: "SemanticVersionMacro")

@freestanding(expression)
public macro semanticVersion(_ string: Int) -> SemanticVersion =
  #externalMacro(module: "SemanticVersionMacroPlugin", type: "SemanticVersionMacro")

@freestanding(expression)
public macro semanticVersion(_ double: Double) -> SemanticVersion =
  #externalMacro(module: "SemanticVersionMacroPlugin", type: "SemanticVersionMacro")
