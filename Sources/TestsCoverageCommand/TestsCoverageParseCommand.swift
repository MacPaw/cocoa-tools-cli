public import ArgumentParser
import Foundation

#if canImport(XCResultParsing)
  import XCResultParsing
#endif

struct TestsCoverageParseCommand: AsyncParsableCommand {
  static let configuration: CommandConfiguration = CommandConfiguration(commandName: "parse")

  @OptionGroup
  var options: Options

  func validate() throws {
    #if canImport(XCResultParsing)
      guard let xcresult = options.xcresult else {
        throw ValidationError("--xcresult is required")
      }
      guard FileManager.default.fileExists(atPath: xcresult) else {
        throw ValidationError("xcresult bundle not found: \(xcresult)")
      }
    #else
      if options.xcresult != nil {
        throw ValidationError("This command requires macOS.")
      }
    #endif
  }

  func run() async throws {
    #if canImport(XCResultParsing)
      let xcresultURL = URL(fileURLWithPath: options.xcresult!)
      let report = try CoverageReport.load(from: xcresultURL)
      let pct = String(format: "%.1f%%", report.lineCoverage * 100)
      print("Coverage: \(report.coveredLines)/\(report.executableLines) lines (\(pct))")
      for target in report.targets {
        let tpct = String(format: "%.1f%%", target.lineCoverage * 100)
        print("  \(target.name): \(target.coveredLines)/\(target.executableLines) (\(tpct))")
      }
    #endif
  }
}
