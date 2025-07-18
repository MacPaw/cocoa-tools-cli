import Foundation

/// Token representing a lexed item.
struct Token: Sendable {
  let type: TokenType
  let value: String
  let position: Int
}

extension Token {
  /// Token types for lexical analysis.
  enum TokenType: Sendable {
    case eof
    case error
    case text
    case variable
    case leftDelim  // ${
    case rightDelim  // }
    case plus  // +
    case dash  // -
    case equals  // =
    case questionMark  // ?
    case colonDash  // :-
    case colonEquals  // :=
    case colonPlus  // :+
    case colonQuestionMark  // :?

    var stringRepresentation: String {
      switch self {
      case .plus: return "+"
      case .dash: return "-"
      case .equals: return "="
      case .questionMark: return "?"
      case .colonDash: return ":-"
      case .colonEquals: return ":="
      case .colonPlus: return ":+"
      case .colonQuestionMark: return ":?"
      default: return ""
      }
    }
  }
}
