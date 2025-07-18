import Foundation

/// Base protocol for AST nodes.
protocol Node: Sendable {
  func evaluate(environment: inout [String: String], options: EnvSubst.Options) throws(EnvSubst.Error) -> String
}

/// Text node for plain text.
struct TextNode: Node {
  let text: String

  func evaluate(environment: inout [String: String], options: EnvSubst.Options) throws(EnvSubst.Error) -> String {
    text
  }
}

/// Variable node for simple variables like $VAR.
struct VariableNode: Node {
  let name: String

  func evaluate(environment: inout [String: String], options: EnvSubst.Options) throws(EnvSubst.Error) -> String {
    // Special case: single underscore is invalid in substitutions
    if name == "_" { throw .invalidExpression("Invalid variable: _") }

    let value = environment[name]

    // Handle unset variables
    guard let value else {
      if options.noUnset { throw .unsetVariable(name) }
      return ""  // Return empty string for unset variables when noUnset is false
    }

    // Handle set but empty variables
    if value.isEmpty && options.noEmpty { throw .emptyVariable(name) }

    return value
  }

  private func isSet(in environment: [String: String]) -> Bool { environment[name] != nil }

  private func isEmpty(in environment: [String: String]) -> Bool { environment[name]?.isEmpty ?? true }
}

/// Substitution node for complex expressions like ${VAR-default}.
struct SubstitutionNode: Node {
  let variable: VariableNode
  let operatorType: Token.TokenType?
  let defaultValue: Node?

  func evaluate(environment: inout [String: String], options: EnvSubst.Options) throws(EnvSubst.Error) -> String {
    guard let operatorType = operatorType, let defaultValue = defaultValue else {
      return try variable.evaluate(environment: &environment, options: options)
    }

    let isSet = environment[variable.name] != nil
    let value = environment[variable.name] ?? ""
    let isEmpty = value.isEmpty

    switch operatorType {
    // MARK: Use a default value
    //
    // ${PARAMETER:-WORD}
    // ${PARAMETER-WORD}
    //
    // If the parameter PARAMETER is unset (never was defined) or null (empty), this one expands to WORD, otherwise it expands to the value of PARAMETER, as if it just was ${PARAMETER}.
    // If you omit the : (colon), like shown in the second form, the default value is only used when the parameter was unset, not when it was empty.
    case .colonDash:
      // ${var:-default} - use default if var not set or empty
      if !isSet || isEmpty { return try defaultValue.evaluate(environment: &environment, options: options) }
      return try variable.evaluate(environment: &environment, options: options)

    case .dash:
      // ${var-default} - use default if var not set
      if !isSet { return try defaultValue.evaluate(environment: &environment, options: options) }
      return try variable.evaluate(environment: &environment, options: options)

    // MARK: Assign a default value
    //
    // ${PARAMETER:=WORD}
    // ${PARAMETER=WORD}
    //
    // This one works like the using default values, but the default text you give is not only expanded, but also assigned to the parameter, if it was unset or null.
    // Equivalent to using a default value, when you omit the : (colon), as shown in the second form, the default value will only be assigned when the parameter was unset.
    case .colonEquals:
      // ${var:=default} - set and use default if var not set or empty
      if !isSet || isEmpty {
        let value = try defaultValue.evaluate(environment: &environment, options: options)
        environment[variable.name] = value
        return value
      }
      return try variable.evaluate(environment: &environment, options: options)
    case .equals:
      // ${var=default} - set and use default if var not set
      if !isSet {
        let value = try defaultValue.evaluate(environment: &environment, options: options)
        environment[variable.name] = value
        return value
      }
      return try variable.evaluate(environment: &environment, options: options)

    // MARK: Use an alternate value
    //
    // ${PARAMETER:+WORD}
    // ${PARAMETER+WORD}
    //
    // This form expands to nothing if the parameter is unset or empty. If it is set, it does not expand to the parameter's value, but to some text you can specify:
    // If the parameter PARAMETER is set, this one expands to WORD, otherwise it expands to an empty string.
    // If you omit the colon, as shown in the second form (${PARAMETER+WORD}), the alternate value will be used if the parameter is set (and it can be empty)! You can use it, for example, to complain if variables you need (and that can be empty) are undefined:
    case .colonPlus:
      // ${var:+alternate} - use alternate if var is set and not empty
      if isSet && !isEmpty { return try defaultValue.evaluate(environment: &environment, options: options) }
      return ""

    case .plus:
      // ${var+alternate} - use alternate if var is set
      if isSet { return try defaultValue.evaluate(environment: &environment, options: options) }
      return ""

    // MARK: Display error if null or unset
    //
    // ${PARAMETER:?WORD}
    // ${PARAMETER?WORD}
    //
    // If the parameter PARAMETER is unset or empty, this one expands to WORD, otherwise it expands to the value of PARAMETER, as if it just was ${PARAMETER}.
    // If you omit the : (colon), like shown in the second form, the error text is only used when the parameter was unset, not when it was empty.
    case .colonQuestionMark:
      // ${var:?error} - use error if var is unset or empty
      if !isSet { throw .unsetVariable(variable.name) }
      if isEmpty { throw .emptyVariable(variable.name) }
      return try variable.evaluate(environment: &environment, options: options)

    case .questionMark:
      // ${var?error} - use error if var is unset
      if !isSet { throw .unsetVariable(variable.name) }
      return try variable.evaluate(environment: &environment, options: options)

    default: throw .invalidExpression("Unknown operator: \(operatorType)")
    }
  }
}

/// Compound node for multiple child nodes.
struct CompoundNode: Node {
  let nodes: [Node]

  func evaluate(environment: inout [String: String], options: EnvSubst.Options) throws(EnvSubst.Error) -> String {
    var result = ""
    for node in nodes { result += try node.evaluate(environment: &environment, options: options) }
    return result
  }
}
