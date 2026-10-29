public import ArgumentParser
import Foundation

#if os(macOS)
  import XCResultParsing
#endif

struct TestsCoverageParseCommand: AsyncParsableCommand {
  static let configuration: CommandConfiguration = CommandConfiguration(commandName: "parse")

  @OptionGroup
  var options: Options

  func validate() throws {
    #if os(macOS)
      guard let xcresult = options.xcresult else {
        throw ValidationError("--xcresult is required")
      }
      guard FileManager.default.fileExists(atPath: xcresult) else {
        throw ValidationError("xcresult bundle not found: \(xcresult)")
      }
    #else
      throw ValidationError("--xcresult is only supported on macOS")
    #endif
  }

  func run() async throws {
    #if os(macOS)
      let xcresultURL = URL(fileURLWithPath: options.xcresult ?? "")
      let report = try XCResultCoverage.load(from: xcresultURL)
      let pct = unsafe String(format: "%.1f%%", report.lineCoverage * 100)
      print("Coverage: \(report.coveredLines)/\(report.executableLines) lines (\(pct))")
      for target in report.targets {
        let tpct = unsafe String(format: "%.1f%%", target.lineCoverage * 100)
        print("  \(target.name): \(target.coveredLines)/\(target.executableLines) (\(tpct))")
      }
    #endif
  }
}
