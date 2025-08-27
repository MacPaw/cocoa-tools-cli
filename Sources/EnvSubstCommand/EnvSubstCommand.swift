import ArgumentParser
@_exported public import EnvSubst
import Foundation

/// Command-line interface for environment variable substitution.
///
/// This command provides a CLI wrapper around the EnvSubst module, allowing users to
/// substitute environment variables in text files or stdin using shell-style variable expansion.
/// Supports various substitution patterns including default values, alternate values, and error handling.
public struct EnvSubstCommand: ParsableCommand {
  /// Configuration for the ArgumentParser command.
  public static let configuration = CommandConfiguration(
    commandName: "envsubst",
    abstract: "Environment variables substitution",
    discussion: """
      Substitute environment variables in text using shell-style variable expansion.

      Supported variable expressions:
      • $var or ${var}           - Value of var
      • ${var-default}           - Use default if var not set
      • ${var:-default}          - Use default if var not set or empty
      • ${var+alternate}         - Use alternate if var is set
      • ${var:+alternate}        - Use alternate if var is set and not empty
      • $$var                    - Escape to literal $var

      Examples:
        echo 'Hello $USER from $HOME' | mpct envsubst
        mpct envsubst -i template.txt -o output.txt
        mpct envsubst --no-unset --fail-fast < input.txt
      """,
  )

  /// Input file path.
  ///
  /// If not specified, reads from stdin.
  @Option(name: [.short, .long], help: "Input file (default: stdin)")
  var input: String?

  /// Output file path.
  ///
  /// If not specified, writes to stdout.
  @Option(name: [.short, .long], help: "Output file (default: stdout)")
  var output: String?

  /// Command options for controlling substitution behavior.
  @OptionGroup
  var options: Options

  /// Creates a new EnvSubstCommand instance.
  public init() {}

  /// Executes the environment variable substitution command.
  ///
  /// Reads input from the specified file or stdin, performs environment variable
  /// substitution using the configured options, and writes the result to the
  /// specified output file or stdout.
  ///
  /// - Throws: ValidationError if file operations fail or substitution encounters errors.
  public func run() throws {
    // Create EnvSubst instance
    let envSubst = EnvSubst(environment: ProcessInfo.processInfo.environment, options: options.options)

    // Read input
    let inputText: String
    if let inputFile = input {
      do { inputText = try String(contentsOfFile: inputFile, encoding: .utf8) }
      catch { throw ValidationError("Failed to read input file '\(inputFile)': \(error.localizedDescription)") }
    }
    else {
      // Read from stdin
      inputText = readFromStdin()
    }

    // Perform substitution
    let result: String
    do { result = try envSubst.substitute(inputText) }
    catch { throw ValidationError("Substitution failed: \(error.localizedDescription)") }

    // Write output
    if let outputFile = output {
      do { try result.write(toFile: outputFile, atomically: true, encoding: .utf8) }
      catch { throw ValidationError("Failed to write output file '\(outputFile)': \(error.localizedDescription)") }
    }
    else {
      // Write to stdout
      print(result, terminator: "")
    }
  }

  /// Reads all input from stdin until EOF.
  ///
  /// - Returns: The complete input as a string with newlines preserved.
  private func readFromStdin() -> String {
    var input = ""
    while let line = readLine(strippingNewline: false) { input += line }
    return input
  }
}
