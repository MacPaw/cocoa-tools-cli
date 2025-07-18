import Foundation

/// Lexer for tokenizing input string.
final class Lexer {
  private let input: String
  private var position: String.Index
  private var start: String.Index
  private var tokens: [Token] = []

  init(input: String, noDigit: Bool = false) {
    self.input = input
    self.position = input.startIndex
    self.start = input.startIndex
  }

  func tokenize() -> [Token] {
    tokens.removeAll()

    while !isAtEnd {
      start = position
      scanToken()
    }

    tokens.append(Token(type: .eof, value: "", position: input.distance(from: input.startIndex, to: position)))
    return tokens
  }

  private var isAtEnd: Bool { position >= input.endIndex }

  @discardableResult
  private func advance() -> Character? {
    guard !isAtEnd else { return nil }
    let char = input[position]
    position = input.index(after: position)
    return char
  }

  private func peek() -> Character? {
    guard !isAtEnd else { return nil }
    return input[position]
  }

  private func peekNext() -> Character? {
    let nextIndex = input.index(after: position)
    guard nextIndex < input.endIndex else { return nil }
    return input[nextIndex]
  }

  private func scanToken() {
    guard let char = advance() else { return }

    switch char {
    case "$": scanDollar()
    default: scanText()
    }
  }

  private func scanDollar() {
    guard let next = peek() else {
      addTextToken()
      return
    }

    switch next {
    case "$":
      // Escaped dollar: $$var -> $var
      advance()  // consume second $
      start = input.index(before: position)  // Move start to point to single $
      addTextToken()
    case "{":
      advance()  // consume {
      addToken(.leftDelim)
    case let c where c.isLetter || c == "_": scanVariable()
    default: addTextToken()
    }
  }

  private func scanVariable() {
    while let char = peek(), char.isAlphanumeric || char == "_" { advance() }

    addToken(.variable)
  }

  private func scanText() {
    while !isAtEnd && peek() != "$" { advance() }
    addTextToken()
  }

  private func scanSubstitutionContent() {
    guard let char = advance() else { return }

    switch char {
    case "}": addToken(.rightDelim)
    case "+": addToken(.plus)
    case "-": addToken(.dash)
    case "=": addToken(.equals)
    case "?": addToken(.questionMark)
    case ":":
      guard let next = peek() else {
        addTextToken()
        return
      }

      advance()  // consume the character after ':'
      switch next {
      case "-": addToken(.colonDash)
      case "=": addToken(.colonEquals)
      case "+": addToken(.colonPlus)
      case "?": addToken(.colonQuestionMark)
      default: addTextToken()
      }
    case "$": scanDollar()
    default: scanSubstitutionText()
    }
  }

  private func scanSubstitutionText() {
    while !isAtEnd {
      let char = peek()
      if char == "}" || char == "$" { break }
      advance()
    }
    addTextToken()
  }

  private func addToken(_ type: Token.TokenType) {
    let value = String(input[start..<position])
    let pos = input.distance(from: input.startIndex, to: start)
    tokens.append(Token(type: type, value: value, position: pos))
  }

  private func addTextToken() { addToken(.text) }
}

// MARK: - Enhanced Lexer for Substitution Context

extension Lexer {
  func tokenizeWithSubstitutionSupport() -> [Token] {
    tokens.removeAll()
    var substitutionDepth = 0

    while !isAtEnd {
      start = position

      if substitutionDepth > 0 {
        scanInSubstitution(&substitutionDepth)
      }
      else {
        scanInText(&substitutionDepth)
      }
    }

    tokens.append(Token(type: .eof, value: "", position: input.distance(from: input.startIndex, to: position)))
    return tokens
  }

  private func scanInText(_ substitutionDepth: inout Int) {
    guard let char = advance() else { return }

    switch char {
    case "$": handleDollarInText(&substitutionDepth)
    default: scanText()
    }
  }

  private func handleDollarInText(_ substitutionDepth: inout Int) {
    guard let next = peek() else {
      addTextToken()
      return
    }

    switch next {
    case "$":
      // Escaped dollar
      advance()
      start = input.index(before: position)  // Move start to point to single $
      addTextToken()
    case "{":
      advance()
      substitutionDepth += 1
      addToken(.leftDelim)
    case let c where c.isLetter || c == "_": scanVariable()
    default: addTextToken()
    }
  }

  private func scanInSubstitution(_ substitutionDepth: inout Int) {
    guard let char = advance() else { return }

    switch char {
    case "}":
      substitutionDepth -= 1
      addToken(.rightDelim)
    case "+": addToken(.plus)
    case "-": addToken(.dash)
    case "=": addToken(.equals)
    case "?": addToken(.questionMark)
    case ":": handleColonInSubstitution()
    case "$": handleDollarInSubstitution(&substitutionDepth)
    case let c where c.isLetter || c == "_":
      // Variable name inside substitution (without $ prefix)
      scanVariableInSubstitution()
    default: scanSubstitutionText()
    }
  }

  private func scanVariableInSubstitution() {
    // We already consumed the first character, continue with the rest
    while let char = peek(), char.isAlphanumeric || char == "_" { advance() }

    addToken(.variable)
  }

  private func handleColonInSubstitution() {
    guard let next = peek() else {
      addTextToken()
      return
    }

    advance()
    switch next {
    case "-": addToken(.colonDash)
    case "=": addToken(.colonEquals)
    case "+": addToken(.colonPlus)
    case "?": addToken(.colonQuestionMark)
    default:
      // Put back the character and treat as text
      position = input.index(before: position)
      addTextToken()
    }
  }

  private func handleDollarInSubstitution(_ substitutionDepth: inout Int) {
    guard let next = peek() else {
      addTextToken()
      return
    }

    switch next {
    case "{":
      advance()
      substitutionDepth += 1
      addToken(.leftDelim)
    case let c where c.isLetter || c == "_": scanVariable()
    default: addTextToken()
    }
  }
}

// MARK: - Extensions

extension Character { fileprivate var isAlphanumeric: Bool { isLetter || isNumber } }
