public import Foundation

#if canImport(FoundationXML)
  public import FoundationXML
#endif

final class XUnitSAXParser: NSObject, XMLParserDelegate, @unchecked Sendable {
  private var suites: [XUnitReport.TestSuite] = []

  // Current <testsuite> state
  private var suiteName: String?
  private var suiteTests = 0
  private var suiteFailures = 0
  private var suiteErrors = 0
  private var suiteSkipped = 0
  private var suiteTime = 0.0
  private var testCases: [XUnitReport.TestSuite.TestCase] = []

  // Current <testcase> state
  private var testCaseClassName: String?
  private var testCaseName: String?
  private var testCaseTime = 0.0
  private var pendingFailure: XUnitReport.TestSuite.TestCase.Failure?
  private var testCaseIsSkipped = false

  // Current <failure> state
  private var failureMessage: String?
  private var failureType: String?
  private var characters = ""

  private var parseError: (any Error)?

  func parse(data: Data) throws -> XUnitReport {
    let xmlParser = XMLParser(data: data)
    xmlParser.externalEntityResolvingPolicy = .never
    #if canImport(FoundationXML)
      xmlParser.delegate = self
    #else
      unsafe xmlParser.delegate = self
    #endif
    // Linux: Returns YES in the event of a successful parse, and NO in case of error.
    _ = xmlParser.parse()
    if let error = parseError {
      throw error
    }
    return XUnitReport(testSuites: suites)
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI _: String?,
    qualifiedName _: String?,
    attributes: [String: String] = [:],
  ) {
    characters = ""
    switch elementName {
    case "testsuite":
      suiteName = attributes["name"]
      suiteTests = Int(attributes["tests"] ?? "") ?? 0
      suiteFailures = Int(attributes["failures"] ?? "") ?? 0
      suiteErrors = Int(attributes["errors"] ?? "") ?? 0
      suiteSkipped = Int(attributes["skipped"] ?? "") ?? 0
      suiteTime = Double(attributes["time"] ?? "") ?? 0
      testCases = []
    case "testcase":
      testCaseClassName = attributes["classname"]
      testCaseName = attributes["name"]
      testCaseTime = Double(attributes["time"] ?? "") ?? 0
      pendingFailure = nil
      testCaseIsSkipped = false
    case "failure":
      failureMessage = attributes["message"]
      failureType = attributes["type"]
    case "skipped":
      testCaseIsSkipped = true
    default:
      break
    }
  }

  func parser(_: XMLParser, foundCharacters string: String) {
    characters += string
  }

  func parser(
    _: XMLParser,
    didEndElement elementName: String,
    namespaceURI _: String?,
    qualifiedName _: String?,
  ) {
    switch elementName {
    case "failure":
      let body = characters.trimmingCharacters(in: .whitespacesAndNewlines)
      pendingFailure = XUnitReport.TestSuite.TestCase.Failure(
        message: failureMessage ?? "",
        type: failureType ?? "",
        body: body.isEmpty ? nil : body,
      )
    case "testcase":
      guard let className = testCaseClassName, let name = testCaseName else { return }
      testCases.append(
        XUnitReport.TestSuite.TestCase(
          className: className,
          name: name,
          time: testCaseTime,
          failure: pendingFailure,
          isSkipped: testCaseIsSkipped,
        )
      )
    case "testsuite":
      guard let name = suiteName else { return }
      suites.append(
        XUnitReport.TestSuite(
          name: name,
          tests: suiteTests,
          failures: suiteFailures,
          errors: suiteErrors,
          skipped: suiteSkipped,
          time: suiteTime,
          testCases: testCases,
        )
      )
    default:
      break
    }
  }

  func parser(_: XMLParser, parseErrorOccurred error: any Error) {
    parseError = error
  }
}
