import Foundation

/// A namespace for CLI tools.
public enum Shell {
  /// Returns path to the provided `cliToolName`.
  ///
  /// - Parameter:
  ///   - cliToolName: A tool name to locate.
  ///
  /// - Returns: The URL of the tool.
  ///
  /// - Throws: An error if the tool cannot be found.
  public static func which(cliToolName: String) throws -> URL {
    do {
      let cliPath: String = try run(executableURL: URL(fileURLWithPath: "/usr/bin/which"), arguments: [cliToolName])
      return URL(fileURLWithPath: cliPath)
    }
    catch { throw Error("Can't find \(cliToolName) command line tool") }
  }

  /// Returns evaluated expression.
  ///
  /// - Parameters:
  ///   - expression: An expression to evaluate.
  ///   - environment: An environment to use for evaluation.
  ///   - trim: Whether to trim the output.
  ///
  /// - Returns: The evaluated expression.
  ///
  /// - Throws: An error if expression can't be evaluated.
  public static func eval(expression: String, environment: [String: String]? = .none, trim: Bool = true) throws
    -> String
  {
    try run(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "eval \"\(expression)\""],
      environment: environment,
      trim: trim,
    )
  }

  /// Returns stdout `Data` returned by the execution of `executableURL` with given `arguments`.
  ///
  /// - Parameters:
  ///   - executableURL: An URL to the executable to run.
  ///   - arguments: A list of arguments to pass to the executable invocation.
  ///   - currentDirectoryURL: A working directory URL where executable will be launched.
  ///   - environment: An environment to use for the execution.
  ///   - trim: Whether to trim the output.
  ///
  /// - Returns: The stdout returned by the execution of `executableURL` with given `arguments`.
  ///
  /// - Throws: An error if tool exits with non-zero status code, or the stdout cannot be parsed.
  public static func run(
    executableURL: URL,
    arguments: [String],
    currentDirectoryURL: URL? = .none,
    environment: [String: String]? = .none,
    trim: Bool = true,
  ) throws -> Data {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    if let environment { process.environment = environment }

    try process.run()
    process.waitUntilExit()

    let stdoutData: Data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

    guard process.terminationStatus == 0 else {
      let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      var stderr: String? = String(data: stderrData, encoding: .utf8)
      if trim { stderr = stderr?.trimmingCharacters(in: .whitespacesAndNewlines) }
      guard let stderr else { throw Error("Can't parse stderr output from the \(executableURL.filePath)") }

      var stdout: String? = String(data: stdoutData, encoding: .utf8)
      if trim { stdout = stdout?.trimmingCharacters(in: .whitespacesAndNewlines) }
      guard let stdout else { throw Error("Can't parse stdout output from the \(executableURL.filePath)") }

      throw Error(
        "Error running \(executableURL.filePath) with arguments \(arguments.joined(separator: " ")). Output:\n\(stdout).\nError:\n\(stderr)."
      )
    }

    return stdoutData
  }

  /// Returns stdout `String` returned by the execution of `executableURL` with given `arguments`.
  ///
  /// - Parameters:
  ///   - executableURL: An URL to the executable to run.
  ///   - arguments: A list of arguments to pass to the executable invocation.
  ///   - currentDirectoryURL: A working directory URL where executable will be launched.
  ///   - environment: An environment to use for the execution.
  ///   - trim: Whether to trim the output.
  ///
  /// - Returns: The stdout returned by the execution of `executableURL` with given `arguments`.
  ///
  /// - Throws: An error if tool exits with non-zero status code, or the stdout cannot be parsed.
  @discardableResult
  public static func run(
    executableURL: URL,
    arguments: [String],
    currentDirectoryURL: URL? = .none,
    environment: [String: String]? = .none,
    trim: Bool = true,
  ) throws -> String {
    let stdoutData: Data = try run(
      executableURL: executableURL,
      arguments: arguments,
      currentDirectoryURL: currentDirectoryURL,
      environment: environment,
      trim: trim,
    )

    var stdoutString: String? = String(data: stdoutData, encoding: .utf8)
    if trim { stdoutString = stdoutString?.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard let stdoutString else { throw Error("Can't parse stdout output from the \(executableURL.filePath)") }

    return stdoutString
  }
}
