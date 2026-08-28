public import ArgumentParser
import Foundation
import XCResultParsing

struct TestsCoverageParseCommand: AsyncParsableCommand {
  static let configuration: CommandConfiguration = CommandConfiguration(commandName: "parse")

  @OptionGroup
  var options: Options

  func validate() throws {
    guard FileManager.default.fileExists(atPath: options.xcresult) else {
      throw ValidationError("xcresult bundle not found: \(options.xcresult)")
    }
  }

  func run() async throws {
    let xcresultURL = URL(fileURLWithPath: options.xcresult)
    let report = try CoverageReport.load(from: xcresultURL)
    let pct = String(format: "%.1f%%", report.lineCoverage * 100)
    print("Coverage: \(report.coveredLines)/\(report.executableLines) lines (\(pct))")
    for target in report.targets {
      let tpct = String(format: "%.1f%%", target.lineCoverage * 100)
      print("  \(target.name): \(target.coveredLines)/\(target.executableLines) (\(tpct))")
    }
  }
}
