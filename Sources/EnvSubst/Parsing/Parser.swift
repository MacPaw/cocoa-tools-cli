import Foundation

/// Parser for building AST from tokens.
final class Parser {
  private let tokens: [Token]
  private var current = 0

  init(tokens: [Token]) { self.tokens = tokens }

  func parse() throws(EnvSubst.Error) -> [Node] {
    var nodes: [Node] = []

    while !isAtEnd {
      let token = advance()

      switch token.type {
      case .eof: break
      case .error: throw .invalidExpression(token.value)
      case .text: nodes.append(TextNode(text: token.value))
      case .variable:
        let varName = String(token.value.dropFirst())  // Remove $
        nodes.append(VariableNode(name: varName))
      case .leftDelim:
        let substitution = try parseSubstitution()
        nodes.append(substitution)
      default: nodes.append(TextNode(text: token.value))
      }
    }

    return nodes
  }

  private func parseSubstitution() throws(EnvSubst.Error) -> SubstitutionNode {
    // Expect variable after ${
    let varToken = advance()
    guard varToken.type == .variable else { throw .invalidExpression("Expected variable after ${") }

    // Variables inside ${} don't have $ prefix, but simple $VAR variables do
    let varName = varToken.value.hasPrefix("$") ? String(varToken.value.dropFirst()) : varToken.value
    let variable = VariableNode(name: varName)

    // Check for operator
    let nextToken = advance()

    guard nextToken.type != .rightDelim else {
      // Simple substitution: ${var}
      return SubstitutionNode(variable: variable, operatorType: nil, defaultValue: nil)
    }

    let operatorType = nextToken.type

    // Parse default value
    var defaultNodes: [Node] = []

    while !isAtEnd {
      let token = advance()

      switch token.type {
      case .rightDelim:
        // End of substitution
        let defaultValue: Node?
        if defaultNodes.isEmpty {
          defaultValue = nil
        }
        else if defaultNodes.count == 1 {
          defaultValue = defaultNodes[0]
        }
        else {
          defaultValue = CompoundNode(nodes: defaultNodes)
        }

        return SubstitutionNode(variable: variable, operatorType: operatorType, defaultValue: defaultValue)

      case .variable:
        // Variables in default value position should be treated based on whether they have $ prefix
        if token.value.hasPrefix("$") {
          let varName = String(token.value.dropFirst())
          defaultNodes.append(VariableNode(name: varName))
        }
        else {
          // This is likely text that was incorrectly tokenized as a variable
          defaultNodes.append(TextNode(text: token.value))
        }

      case .text, .plus, .dash, .equals, .questionMark, .colonDash, .colonEquals, .colonPlus, .colonQuestionMark:
        defaultNodes.append(TextNode(text: token.value))

      case .eof: throw .invalidExpression("Closing brace expected")

      default: defaultNodes.append(TextNode(text: token.value))
      }
    }

    throw .invalidExpression("Closing brace expected")
  }

  private var isAtEnd: Bool { current >= tokens.count || tokens[current].type == .eof }

  private func advance() -> Token {
    if !isAtEnd { current += 1 }
    return tokens[current - 1]
  }
}
