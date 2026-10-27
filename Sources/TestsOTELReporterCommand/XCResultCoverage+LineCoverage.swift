#if os(macOS)
  import TestsOTELReporter
  import XCResultParsing

  extension LineCoverage {
    /// Path extension of the test bundles `xccov` lists as targets.
    private static let testBundleExtension: String = "xctest"

    /// Creates per-target line coverage from `.xcresult` coverage.
    ///
    /// Test bundles are dropped unless asked for: their own coverage is nearly always 100% and
    /// only dilutes a repository-wide view of how well the code under test is covered. A test
    /// bundle is recognized by its build product living inside a `*.xctest` directory, since the
    /// target name itself carries no extension.
    ///
    /// - Parameters:
    ///   - xcresultCoverage: The parsed `.xcresult` coverage.
    ///   - includeTestTargets: Whether test bundle targets (`*.xctest`) are kept.
    init(xcresultCoverage: XCResultCoverage, includeTestTargets: Bool) {
      self.init(
        targets:
          xcresultCoverage.targets
          .filter { includeTestTargets || !Self.isTestBundle($0) }
          .map { Target(name: $0.name, coveredLines: $0.coveredLines, executableLines: $0.executableLines) }
      )
    }

    /// Whether a target is a test bundle.
    ///
    /// - Parameter target: The target to inspect.
    /// - Returns: `true` when the target's build product is inside a `*.xctest` bundle.
    private static func isTestBundle(_ target: XCResultCoverage.Target) -> Bool {
      target.buildProductPath.split(separator: "/").contains { $0.hasSuffix(".\(testBundleExtension)") }
    }
  }
#endif
