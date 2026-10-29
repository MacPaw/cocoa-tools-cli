/// Line coverage of a test run, per target, independent of the report format it was parsed from.
///
/// Both `.xcresult` bundles and LLVM coverage exports are normalized into this model before any
/// OpenTelemetry metrics are derived, so the reporter never depends on a particular parser.
public struct LineCoverage {
  /// Coverage of each target, in report order.
  public var targets: [Target]

  /// Initializes a coverage report.
  ///
  /// - Parameter targets: Coverage of each target.
  public init(targets: [Target]) {
    self.targets = targets
  }
}

extension LineCoverage {
  /// Line coverage of a single target.
  public struct Target {
    /// Name of the target.
    public var name: String
    /// Number of executable lines that were executed.
    public var coveredLines: Int
    /// Number of executable lines in the target.
    public var executableLines: Int

    /// Initializes a target.
    ///
    /// - Parameters:
    ///   - name: Name of the target.
    ///   - coveredLines: Number of executable lines that were executed.
    ///   - executableLines: Number of executable lines in the target.
    public init(name: String, coveredLines: Int, executableLines: Int) {
      self.name = name
      self.coveredLines = coveredLines
      self.executableLines = executableLines
    }

    /// Number of executable lines that were not executed.
    public var uncoveredLines: Int { max(executableLines - coveredLines, 0) }
  }
}

extension LineCoverage: Sendable {}
extension LineCoverage: Equatable {}
extension LineCoverage.Target: Sendable {}
extension LineCoverage.Target: Equatable {}
