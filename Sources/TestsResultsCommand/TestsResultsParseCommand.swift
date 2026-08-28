public import ArgumentParser
import Foundation

#if os(macOS)
  import XCResultParsing
#endif

struct TestsResultsParseCommand: AsyncParsableCommand {
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
    #endif
  }

  func run() async throws {
    #if os(macOS)
      let xcresultURL = URL(fileURLWithPath: options.xcresult!)
      let cli = XCResultToolCLI()
      let data = try cli.getTestResultsTests(xcresultPath: xcresultURL)
      let results = try JSONDecoder().decode(TestResults.self, from: data)
      print("Test groups: \(results.testNodes.count)")
      print("Devices: \(results.devices.map(\.deviceName).joined(separator: ", "))")
    #endif
  }
}
