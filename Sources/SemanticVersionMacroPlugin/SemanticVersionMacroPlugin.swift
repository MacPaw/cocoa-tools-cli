//
//  SemanticVersionMacroPlugin.swift
//  mpccli
//
//  Created by Vitalii Budnik on 8/14/25.
//

@_exported public import SemanticVersion
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Macro for generating SemanticVersion instances at compile time.
///
/// This macro parses version strings, integers, or floats and generates SemanticVersion initialization code.
public struct SemanticVersionMacro: ExpressionMacro {
  /// Expands the semantic version macro into Swift syntax.
  ///
  /// - Parameters:
  ///   - node: The macro expansion node from the syntax tree.
  ///   - context: The macro expansion context.
  /// - Returns: The expanded Swift expression syntax.
  /// - Throws: Macro expansion errors if the version cannot be parsed.
  public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext)
    throws -> ExprSyntax
  {
    guard node.arguments.count == 1, let argument: LabeledExprSyntax = node.arguments.first else {
      throw diagnosticsError(
        node,
        error: .init(message: "Macro supports only one argument", topic: .invalidMacroArgument),
      )
    }

    let argumentExpr: ExprSyntax = argument.expression

    let versionString: String =
      if let segments = argumentExpr.as(StringLiteralExprSyntax.self)?.segments, segments.count == 1,
        let segment = segments.first, case .stringSegment(let literalSegment) = segment
      { literalSegment.content.text }
      else if let majorVersionString = argumentExpr.as(IntegerLiteralExprSyntax.self)?.literal.text {
        majorVersionString
      }
      else if let majorMinorVersionString = argumentExpr.as(FloatLiteralExprSyntax.self)?.literal.text {
        majorMinorVersionString
      }
      else {
        throw diagnosticsError(
          node,
          error: .init(
            message: "Unexpected argument. Must be a string literal, integer literal, or float literal",
            topic: .invalidMacroArgument,
          ),
        )
      }

    let version: SemanticVersion
    do { version = try SemanticVersion.build(versionString) }
    catch {
      throw diagnosticsError(
        node,
        error: .init(
          message: "'\(versionString)' can't be parsed as a SemanticVersion: \(error.errorDescription)",
          topic: .invalidVersionValue,
        ),
      )
    }

    return expand(version: version)
  }

  /// Generates Swift syntax for creating a SemanticVersion instance.
  ///
  /// - Parameter version: The semantic version to generate code for.
  /// - Returns: Swift expression syntax for initializing the semantic version.
  public static func expand(version: SemanticVersion) -> ExprSyntax {
    let argumentList: LabeledExprListSyntax = LabeledExprListSyntax {
      LabeledExprSyntax(expression: IntegerLiteralExprSyntax(version.major))
      LabeledExprSyntax(expression: IntegerLiteralExprSyntax(version.minor))
      LabeledExprSyntax(expression: IntegerLiteralExprSyntax(version.patch))

      if !version.prereleaseIdentifiers.isEmpty {
        LabeledExprSyntax(
          label: .identifier("prereleaseIdentifiers"),
          colon: .colonToken(),
          expression: ArrayExprSyntax {
            for prereleaseIdentifier in version.prereleaseIdentifiers {
              ArrayElementSyntax(expression: StringLiteralExprSyntax(content: prereleaseIdentifier))
            }
          },
        )
      }

      if !version.buildMetadataIdentifiers.isEmpty {
        LabeledExprSyntax(
          label: .identifier("buildMetadataIdentifiers"),
          colon: .colonToken(),
          expression: ArrayExprSyntax {
            for buildIdentifier in version.buildMetadataIdentifiers {
              ArrayElementSyntax(expression: StringLiteralExprSyntax(content: buildIdentifier))
            }
          },
        )
      }
    }

    let functionCallExpr = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("SemanticVersion")),
        name: .identifier("init"),
      ),
      leftParen: .leftParenToken(),
      arguments: argumentList,
      rightParen: .rightParenToken(),
    )

    return ExprSyntax(functionCallExpr)
  }
}

@main
struct SemanticVersionMacroPlugin: CompilerPlugin { var providingMacros: [Macro.Type] = [SemanticVersionMacro.self] }

extension SemanticVersionMacro {
  /// Error type for semantic version macro expansion failures.
  public struct MacroError: DiagnosticMessage {
    enum MessageTopic {
      case invalidMacroArgument
      case invalidVersionValue

      var description: String {
        switch self {
        case .invalidMacroArgument: return "Invalid macro argument"
        case .invalidVersionValue: return "Invalid semantic version value"
        }
      }
    }

    /// Unique identifier for the diagnostic message.
    public var diagnosticID: MessageID { MessageID(domain: "SemanticVersionMacro", id: topic.description) }
    /// The diagnostic message text.
    public var message: String
    /// The severity level of the diagnostic.
    public var severity: DiagnosticSeverity

    private var topic: MessageTopic

    init(message: String, topic: MessageTopic, severity: DiagnosticSeverity = .error) {
      self.topic = topic
      self.severity = severity
      self.message = message
    }
  }

  private static func diagnosticsError(_ node: some FreestandingMacroExpansionSyntax, error: MacroError)
    -> DiagnosticsError
  { DiagnosticsError(diagnostics: [.init(node: node, message: error)]) }
}
