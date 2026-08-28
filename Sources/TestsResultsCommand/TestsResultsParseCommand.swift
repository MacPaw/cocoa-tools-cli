public import ArgumentParser
import Foundation
import XCResultParsing

struct TestsResultsParseCommand: AsyncParsableCommand {
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
    let cli = XCResultToolCLI()
    let data = try cli.getTestResultsTests(xcresultPath: xcresultURL)
    let results = try JSONDecoder().decode(TestResults.self, from: data)
    print("Test groups: \(results.testNodes.count)")
    print("Devices: \(results.devices.map(\.deviceName).joined(separator: ", "))")
  }
}
