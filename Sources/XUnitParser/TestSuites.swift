public import Foundation
#if canImport(FoundationXML)
  public import FoundationXML
#endif

// MARK: - Public model

/// Root element of an xUnit XML report, containing one or more test suites.
public struct TestSuites: Sendable {
  /// The test suites contained in this report.
  public let suites: [TestSuite]

  /// Loads and parses an xUnit XML report at the given URL.
  ///
  /// - Parameter url: The file URL of the xUnit XML report.
  /// - Returns: The parsed ``TestSuites`` value.
  /// - Throws: ``XUnitParseError`` if the file cannot be read or the XML is malformed.
  public static func load(from url: URL) throws -> TestSuites {
    let data = try Data(contentsOf: url)
    return try XUnitSAXParser().parse(data: data)
  }
}

/// A single `<testsuite>` element within an xUnit report.
public struct TestSuite: Sendable {
  /// The name of the test suite.
  public let name: String
  /// Total number of test cases.
  public let tests: Int
  /// Number of test cases that failed.
  public let failures: Int
  /// Number of test cases that errored.
  public let errors: Int
  /// Number of test cases that were skipped.
  public let skipped: Int
  /// Total execution time in seconds.
  public let time: Double
  /// The test cases within this suite.
  public let testCases: [TestCase]
}

/// A single `<testcase>` element within a ``TestSuite``.
public struct TestCase: Sendable {
  /// The fully-qualified class name in `ModuleName.SuiteName` format.
  public let classname: String
  /// The test method name.
  public let name: String
  /// Execution time in seconds.
  public let time: Double
  /// Failure details, or `nil` if the test passed or was skipped.
  public let failure: Failure?
  /// `true` when a `<skipped/>` child element was present.
  public let isSkipped: Bool

  /// The module component of ``classname`` (the part before the first `.`).
  public var moduleName: String {
    String(classname.prefix(upTo: classname.firstIndex(of: ".") ?? classname.endIndex))
  }

  /// The suite component of ``classname`` (the part after the first `.`).
  public var suiteName: String {
    guard let dotIndex = classname.firstIndex(of: ".") else { return classname }
    return String(classname[classname.index(after: dotIndex)...])
  }
}

/// A `<failure>` child element of a ``TestCase``.
public struct Failure: Sendable {
  /// The failure message attribute.
  public let message: String
  /// The failure type attribute (e.g. `"Issue"`).
  public let type: String
  /// The text body of the `<failure>` element (stack trace or extended description), if any.
  public let body: String?
}

// MARK: - Errors

/// Errors thrown by ``TestSuites/load(from:)``.
public enum XUnitParseError: Error, Sendable {
  /// The underlying `XMLParser` reported a structural error.
  case xmlParserError(any Error)
}

// MARK: - SAX parser (private)

private final class XUnitSAXParser: NSObject, XMLParserDelegate, @unchecked Sendable {
  private var suites: [TestSuite] = []

  // Current <testsuite> state
  private var suiteName: String?
  private var suiteTests = 0
  private var suiteFailures = 0
  private var suiteErrors = 0
  private var suiteSkipped = 0
  private var suiteTime = 0.0
  private var testCases: [TestCase] = []

  // Current <testcase> state
  private var testCaseClassname: String?
  private var testCaseName: String?
  private var testCaseTime = 0.0
  private var pendingFailure: Failure?
  private var testCaseIsSkipped = false

  // Current <failure> state
  private var failureMessage: String?
  private var failureType: String?
  private var characters = ""

  private var parseError: (any Error)?

  func parse(data: Data) throws -> TestSuites {
    let xmlParser = XMLParser(data: data)
    unsafe xmlParser.delegate = self
    xmlParser.parse()
    if let error = parseError {
      throw XUnitParseError.xmlParserError(error)
    }
    return TestSuites(suites: suites)
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
      testCaseClassname = attributes["classname"]
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
      pendingFailure = Failure(
        message: failureMessage ?? "",
        type: failureType ?? "",
        body: body.isEmpty ? nil : body,
      )
    case "testcase":
      guard let classname = testCaseClassname, let name = testCaseName else { return }
      testCases.append(
        TestCase(
          classname: classname,
          name: name,
          time: testCaseTime,
          failure: pendingFailure,
          isSkipped: testCaseIsSkipped,
        )
      )
    case "testsuite":
      guard let name = suiteName else { return }
      suites.append(
        TestSuite(
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
