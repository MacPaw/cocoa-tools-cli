import Foundation
import Shell
import Testing

@testable import EnvSubst

extension [EnvSubstTests.TestMode] {
  static let never: Self = []
  static let noUnset: Self = [.noUnset, .strict]
  static let noEmpty: Self = [.noEmpty, .strict]
  static let strict: Self = [.noUnset, .noEmpty, .strict]
  static let always: Self = EnvSubstTests.TestMode.allCases
}

@Suite("EnvSubstTests")
struct EnvSubstTests {
  /// Test modes.
  enum TestMode: CaseIterable {
    /// Fail when unset.
    case noUnset
    /// Fail when empty.
    case noEmpty
    /// Fail when unset or empty.
    case strict
    /// Don't fail.
    case relaxed
  }

  private let envSubstOptions: [TestMode: EnvSubst.Options] = [
    .relaxed: .init(), .noUnset: .init(noUnset: true), .noEmpty: .init(noEmpty: true),
    .strict: .init(noUnset: true, noEmpty: true),
  ]

  /// Test case for envsubst functionality.
  struct TestCase {
    let description: String
    let input: String
    let expectedOutput: String?
    let failWhen: [TestMode]
    let checkWithEval: Bool
    let sourceLocation: SourceLocation

    init(
      input: String,
      expectedOutput: String? = .none,
      fail: [TestMode] = [],
      _ description: String,
      eval: Bool = true,
      _ sourceLocation: SourceLocation = #_sourceLocation
    ) {
      self.input = input
      self.expectedOutput = expectedOutput
      self.failWhen = fail
      self.description = description
      self.checkWithEval = eval
      self.sourceLocation = sourceLocation
    }
  }

  // Test cases from Go envsubst - comprehensive test cases
  static let testCases: [TestCase] = [
    // Basic cases that should work
    .init(input: "", expectedOutput: "", fail: .never, "empty"),
    .init(input: "$BAR", expectedOutput: "bar", fail: .never, "env only"),
    .init(input: "$BAR baz", expectedOutput: "bar baz", fail: .never, "with text"),
    .init(input: "$BAR$FOO", expectedOutput: "barfoo", fail: .never, "concatenated"),
    .init(input: "$BAR - $FOO", expectedOutput: "bar - foo", fail: .never, "2 env var"),
    .init(input: "$_ bar", expectedOutput: "", fail: .always, "invalid var"),
    .init(input: "$$_ bar", expectedOutput: "$_ bar", fail: .never, "escaped $", eval: false),
    .init(input: "${_} bar", expectedOutput: "", fail: .always, "invalid var"),
    .init(input: "${BAR}baz", expectedOutput: "barbaz", fail: .never, "value of $var"),
    .init(input: "${_UNDERSCORED}", expectedOutput: "_underscored", fail: .never, "value of $var"),
    .init(input: "$_UNDERSCORED", expectedOutput: "_underscored", fail: .never, "value of $var"),

    .init(input: "${NOTSET-$BAR}", expectedOutput: "bar", fail: .never, "$var not set -"),
    .init(input: "${NOTSET=$BAR}", expectedOutput: "bar", fail: .never, "$var not set ="),

    .init(input: "${EMPTY-$BAR}", expectedOutput: "", fail: .noEmpty, "$var set but empty -"),
    .init(input: "${EMPTY=$BAR}", expectedOutput: "", fail: .noEmpty, "$var set but empty ="),
    .init(input: "${EMPTY:-$BAR}", expectedOutput: "bar", fail: .never, "$var not set or empty :-"),
    .init(input: "${EMPTY:=$BAR}", expectedOutput: "bar", fail: .never, "$var not set or empty :="),

    .init(
      input: "hello $BAR\nhello ${EMPTY:=$FOO}",
      expectedOutput: "hello bar\nhello foo",
      fail: .never,
      "multi line string"
    ),
    .init(
      input: "name: ${NAME:=foo_qux}, key: ${EMPTY:=baz_bar}",
      expectedOutput: "name: foo_qux, key: baz_bar",
      fail: .never,
      "issue #2"
    ),
    .init(
      input: "prop=${HOME_URL-http://localhost:8080}",
      expectedOutput: "prop=http://localhost:8080",
      fail: .never,
      "gh-issue-8"
    ),

    // TODO: fix this
    .init(
      input: "$NOTSET:=wo_rld $ALSO_NOTSET:=bar_baz $EMPTY:=some",
      expectedOutput: ":=wo_rld :=bar_baz :=some",
      fail: .strict,
      "issue #1"
    ),
    .init(
      input: "${NOTSET:=wo_rld} ${ALSO_NOTSET:=bar_baz} ${EMPTY:=some}",
      expectedOutput: "wo_rld bar_baz some",
      fail: .never,
      "issue #1"
    ),

    // Unset-default
    .init(
      input: "${NOTSET--1}",
      expectedOutput: "-1",
      fail: .never,
      "if $var not set, - correctly parse default direct value"
    ),
    .init(
      input: "${NOTSET:--1}",
      expectedOutput: "-1",
      fail: .never,
      "if $var not set, :- correctly parse default direct value"
    ),
    .init(
      input: "${NOTSET=-1}",
      expectedOutput: "-1",
      fail: .never,
      "if $var not set, = correctly parse default direct value"
    ),
    .init(
      input: "${NOTSET:==1}",
      expectedOutput: "=1",
      fail: .never,
      "if $var not set, := correctly parse default direct value"
    ),

    // Single letter
    .init(input: "${A}", expectedOutput: "AAA", fail: .never, "single letter"),

    // Failure point
    .init(input: "hello ${", fail: .always, "closing brace expected"),

    // Unset
    .init(input: "${NOTSET}", expectedOutput: "", fail: .noUnset, "$var not set"),
    .init(input: "$NOTSET", expectedOutput: "", fail: .noUnset, "$var not set"),

    // Empty
    .init(input: "${EMPTY}", expectedOutput: "", fail: .noEmpty, "$var set to empty"),
    .init(input: "$EMPTY", expectedOutput: "", fail: .noEmpty, "$var set to empty"),

    // Set-default
    .init(input: "${BAR-var is set}", expectedOutput: "bar", fail: .never, "$var is set and default provided -"),
    .init(input: "${BAR:-var is set}", expectedOutput: "bar", fail: .never, "$var is set and default provided :-"),
    .init(input: "${BAR=var is set}", expectedOutput: "bar", fail: .never, "$var is set and default provided ="),
    .init(input: "${BAR:=var is set}", expectedOutput: "bar", fail: .never, "$var is set and default provided :="),
    .init(input: "${BAR+var is set}", expectedOutput: "var is set", fail: .never, "$var is set and default provided +"),
    .init(
      input: "${BAR:+var is set}",
      expectedOutput: "var is set",
      fail: .never,
      "$var is set and default provided :+"
    ), .init(input: "${BAR?var is set}", expectedOutput: "bar", fail: .never, "$var is set and default provided ?"),
    .init(input: "${BAR:?var is set}", expectedOutput: "bar", fail: .never, "$var is set and default provided :?"),
    .init(
      input: "${BAR=var is set} $BAR",
      expectedOutput: "bar bar",
      fail: .never,
      "$var is set and default provided =, $var value not changed"
    ),
    .init(
      input: "${BAR:=var is set} $BAR",
      expectedOutput: "bar bar",
      fail: .never,
      "$var is set and default provided :=, $var value not changed"
    ),

    // Set-other
    .init(input: "${BAR-$FOO}", expectedOutput: "bar", fail: .never, "$var and $OTHER are set -"),
    .init(input: "${BAR:-$FOO}", expectedOutput: "bar", fail: .never, "$var and $OTHER are set :-"),
    .init(input: "${BAR=$FOO}", expectedOutput: "bar", fail: .never, "$var and $OTHER are set ="),
    .init(input: "${BAR+$FOO}", expectedOutput: "foo", fail: .never, "$var and $OTHER are set +"),
    .init(input: "${BAR:+$FOO}", expectedOutput: "foo", fail: .never, "$var and $OTHER are set :+"),
    .init(input: "${BAR?$FOO}", expectedOutput: "bar", fail: .never, "$var and $OTHER are set ?"),
    .init(input: "${BAR:?$FOO}", expectedOutput: "bar", fail: .never, "$var and $OTHER are set :?"),
    .init(
      input: "${BAR=$FOO} $BAR",
      expectedOutput: "bar bar",
      fail: .never,
      "$var and $OTHER are set =, $var value not changed"
    ),
    .init(
      input: "${BAR:=$FOO} $BAR",
      expectedOutput: "bar bar",
      fail: .never,
      "$var and $OTHER are set :=, $var value not changed"
    ),

    // Unset-default
    .init(input: "${NOTSET-var is unset}", expectedOutput: "var is unset", fail: .never, "$var and $DEFAULT not set -"),
    .init(
      input: "${NOTSET:-var is unset}",
      expectedOutput: "var is unset",
      fail: .never,
      "$var and $DEFAULT not set :-"
    ),
    .init(input: "${NOTSET=var is unset}", expectedOutput: "var is unset", fail: .never, "$var and $DEFAULT not set ="),
    .init(
      input: "${NOTSET:=var is unset}",
      expectedOutput: "var is unset",
      fail: .never,
      "$var and $DEFAULT not set :="
    ), .init(input: "${NOTSET+var is unset}", expectedOutput: "", fail: .never, "$var and $OTHER not set +"),
    .init(input: "${NOTSET:+var is unset}", expectedOutput: "", fail: .never, "$var and $OTHER not set :+"),
    .init(input: "${NOTSET?var is unset}", expectedOutput: "", fail: .always, "$var and $OTHER not set ?"),
    .init(input: "${NOTSET:?var is unset}", expectedOutput: "", fail: .always, "$var and $OTHER not set :?"),
    .init(input: "${NOTSET+var is unset} $NOTSET", expectedOutput: " ", fail: .noUnset, "$var and $OTHER not set +"),
    .init(input: "${NOTSET:+var is unset} $NOTSET", expectedOutput: " ", fail: .noUnset, "$var and $OTHER not set :+"),
    .init(
      input: "${NOTSET=var is unset} $NOTSET",
      expectedOutput: "var is unset var is unset",
      fail: .never,
      "$var and $DEFAULT not set =, $var is set after"
    ),
    .init(
      input: "${NOTSET:=var is unset} $NOTSET",
      expectedOutput: "var is unset var is unset",
      fail: .never,
      "$var and $DEFAULT not set :=, $var is set after"
    ),

    // Empty-default
    .init(input: "${EMPTY-var is empty}", expectedOutput: "", fail: .noEmpty, "$var and $DEFAULT not set -"),
    .init(
      input: "${EMPTY:-var is empty}",
      expectedOutput: "var is empty",
      fail: .never,
      "$var and $DEFAULT not set :-"
    ), .init(input: "${EMPTY=var is empty}", expectedOutput: "", fail: .noEmpty, "$var and $DEFAULT not set ="),
    .init(
      input: "${EMPTY:=var is empty}",
      expectedOutput: "var is empty",
      fail: .never,
      "$var and $DEFAULT not set :="
    ), .init(input: "${EMPTY+var is empty}", expectedOutput: "var is empty", fail: .never, "$var and $OTHER not set +"),
    .init(input: "${EMPTY:+var is empty}", expectedOutput: "", fail: .never, "$var and $OTHER not set :+"),
    .init(input: "${EMPTY?var is empty}", expectedOutput: "", fail: .noEmpty, "$var and $OTHER not set ?"),
    .init(input: "${EMPTY:?var is empty}", expectedOutput: "", fail: .always, "$var and $OTHER not set :?"),
    .init(input: "${EMPTY=var is empty} $EMPTY", expectedOutput: " ", fail: .noEmpty, "$var and $DEFAULT not set ="),
    .init(
      input: "${EMPTY:=var is empty} $EMPTY",
      expectedOutput: "var is empty var is empty",
      fail: .never,
      "$var not set and $DEFAULT provided with :=, $var is set after"
    ),

    // Unset-unset
    .init(input: "${NOTSET-$ALSO_NOTSET}", expectedOutput: "", fail: .noUnset, "$var and $DEFAULT not set -"),
    .init(input: "${NOTSET:-$ALSO_NOTSET}", expectedOutput: "", fail: .noUnset, "$var and $DEFAULT not set :-"),
    .init(input: "${NOTSET=$ALSO_NOTSET}", expectedOutput: "", fail: .noUnset, "$var and $DEFAULT not set ="),
    .init(input: "${NOTSET:=$ALSO_NOTSET}", expectedOutput: "", fail: .noUnset, "$var and $DEFAULT not set :="),
    .init(input: "${NOTSET+$ALSO_NOTSET}", expectedOutput: "", fail: .never, "$var and $OTHER not set +"),
    .init(input: "${NOTSET:+$ALSO_NOTSET}", expectedOutput: "", fail: .never, "$var and $OTHER not set :+"),
    .init(input: "${NOTSET?$ALSO_NOTSET}", expectedOutput: "", fail: .always, "$var and $OTHER not set ?"),
    .init(input: "${NOTSET:?$ALSO_NOTSET}", expectedOutput: "", fail: .always, "$var and $OTHER not set :?"),

    // Empty-Unset
    .init(input: "${EMPTY-$NOTSET}", expectedOutput: "", fail: .noEmpty, "$var empty and $DEFAULT not set -"),
    .init(input: "${EMPTY:-$NOTSET}", expectedOutput: "", fail: .noUnset, "$var empty and $DEFAULT not set :-"),
    .init(input: "${EMPTY=$NOTSET}", expectedOutput: "", fail: .noEmpty, "$var empty and $DEFAULT not set ="),
    .init(input: "${EMPTY:=$NOTSET}", expectedOutput: "", fail: .noUnset, "$var empty and $DEFAULT not set :="),
    .init(input: "${EMPTY+$NOTSET}", expectedOutput: "", fail: .noUnset, "$var empty and $OTHER not set +"),
    .init(input: "${EMPTY:+$NOTSET}", expectedOutput: "", fail: .never, "$var empty and $OTHER not set :+"),
    .init(input: "${EMPTY?$NOTSET}", expectedOutput: "", fail: .noEmpty, "$var empty and $OTHER not set ?"),
    .init(input: "${EMPTY:?$NOTSET}", expectedOutput: "", fail: .always, "$var empty and $OTHER not set :?"),

    // Unset-empty
    .init(input: "${NOTSET-$EMPTY}", expectedOutput: "", fail: .noEmpty, "$var not set and $DEFAULT empty -"),
    .init(input: "${NOTSET:-$EMPTY}", expectedOutput: "", fail: .noEmpty, "$var not set and $DEFAULT empty :-"),
    .init(input: "${NOTSET=$EMPTY}", expectedOutput: "", fail: .noEmpty, "$var not set and $DEFAULT empty ="),
    .init(input: "${NOTSET:=$EMPTY}", expectedOutput: "", fail: .noEmpty, "$var not set and $DEFAULT empty :="),
    .init(input: "${NOTSET+$EMPTY}", expectedOutput: "", fail: .never, "$var not set and $OTHER empty +"),
    .init(input: "${NOTSET:+$EMPTY}", expectedOutput: "", fail: .never, "$var not set and $OTHER empty :+"),
    .init(input: "${NOTSET?$EMPTY}", expectedOutput: "", fail: .always, "$var empty and $OTHER not set ?"),
    .init(input: "${NOTSET:?$EMPTY}", expectedOutput: "", fail: .always, "$var empty and $OTHER not set :?"),

    // Empty-empty
    .init(input: "${EMPTY-$ALSO_EMPTY}", expectedOutput: "", fail: .noEmpty, "$var and $DEFAULT empty -"),
    .init(input: "${EMPTY:-$ALSO_EMPTY}", expectedOutput: "", fail: .noEmpty, "$var and $DEFAULT empty :-"),
    .init(input: "${EMPTY=$ALSO_EMPTY}", expectedOutput: "", fail: .noEmpty, "$var and $DEFAULT empty ="),
    .init(input: "${EMPTY:=$ALSO_EMPTY}", expectedOutput: "", fail: .noEmpty, "$var and $DEFAULT empty :="),
    .init(input: "${EMPTY+$ALSO_EMPTY}", expectedOutput: "", fail: .noEmpty, "$var and $OTHER empty +"),
    .init(input: "${EMPTY:+$ALSO_EMPTY}", expectedOutput: "", fail: .never, "$var and $OTHER empty :+"),
    .init(input: "${EMPTY?$ALSO_EMPTY}", expectedOutput: "", fail: .noEmpty, "$var and $OTHER empty +"),
    .init(input: "${EMPTY:?$ALSO_EMPTY}", expectedOutput: "", fail: .always, "$var and $OTHER empty :+"),

    // Escaping
    .init(input: "FOO $$BAR BAZ", expectedOutput: "FOO $BAR BAZ", fail: .never, "escape $$var", eval: false),
    .init(input: "FOO $${BAR} BAZ", expectedOutput: "FOO ${BAR} BAZ", fail: .never, "escape $${subst}", eval: false),
    .init(input: "FOO $$BAR BAZ", expectedOutput: "FOO $BAR BAZ", fail: .never, "escape $$var", eval: false),
    .init(input: "FOO $${BAR} BAZ", expectedOutput: "FOO ${BAR} BAZ", fail: .never, "escape $${subst}", eval: false),
    .init(input: "$$$BAR", expectedOutput: "$bar", fail: .never, "escape $$$var", eval: false),
    .init(input: "$$${BAZ:-baz}", expectedOutput: "$baz", fail: .never, "escape $$${subst}", eval: false),

    // Failures
    .init(input: "${NOTSET?error}", expectedOutput: "", fail: .always, "unset ? error"),
    .init(input: "${NOTSET:?error}", expectedOutput: "", fail: .always, "unset :? error"),
    .init(input: "${EMPTY?error}", expectedOutput: "", fail: .noEmpty, "empty ? error"),
    .init(input: "${EMPTY:?error}", expectedOutput: "", fail: .always, "empty :? error"),
    .init(input: "${BAR?error}", expectedOutput: "bar", fail: .never, "set ? error"),
    .init(input: "${BAR:?error}", expectedOutput: "bar", fail: .never, "set :? error"),
  ]

  let fakeEnv: [String: String] = [
    "BAR": "bar", "FOO": "foo", "EMPTY": "", "ALSO_EMPTY": "", "A": "AAA", "_UNDERSCORED": "_underscored",
  ]

  @Test("#substitute handles envsubst test cases (Xcode edition)")
  func test_substitute_handlesEnvsubstTestCases_xcode() async throws {
    for testMode in TestMode.allCases {
      for testCase in Self.testCases { try checkTestCase(testCase: testCase, mode: testMode) }
    }
  }

  // Commented out because it freezes Xcode.
  //   @Test("#substitute handles envsubst test cases", arguments: TestMode.allCases, Self.testCases)
  //   func test_substitute_handlesEnvsubstTestCases(testMode: TestMode, testCase: TestCase) async throws {
  //     try checkTestCase(testCase: testCase, mode: testMode)
  //   }

  private func checkTestCase(testCase: TestCase, mode: TestMode) throws {
    // GIVEN
    let options = try #require(envSubstOptions[mode])
    let sut = EnvSubst(environment: fakeEnv, options: options)

    // WHEN & THEN
    // Test each case with appropriate error expectations
    if testCase.failWhen.contains(mode) {
      #expect(
        throws: (any Error).self,
        "[\(mode)] \(testCase.description): input '\(testCase.input)', result '\((try? sut.substitute(testCase.input)) ?? "")'",
        sourceLocation: testCase.sourceLocation
      ) { try sut.substitute(testCase.input) }
    }
    else {
      let expectedOutput = try #require(
        testCase.expectedOutput,
        "[\(mode)] output must be set",
        sourceLocation: testCase.sourceLocation
      )
      do {
        let result = try sut.substitute(testCase.input)
        #expect(
          result == testCase.expectedOutput,
          "[\(mode)] \(testCase.description): input: '\(testCase.input)', got '\(result)', expected '\(expectedOutput)'",
          sourceLocation: testCase.sourceLocation
        )
      }
      catch {
        #expect(
          Bool(false),
          "[\(mode)] unexpected error: \(error), input: '\(testCase.input)', expected '\(expectedOutput)'",
          sourceLocation: testCase.sourceLocation
        )
      }

      if testCase.checkWithEval {
        do {
          let result = try Shell.eval(expression: "echo '\(testCase.input)'", environment: fakeEnv, trim: false)
            .trimmingCharacters(in: .newlines)
          #expect(
            result == testCase.expectedOutput,
            "[\(mode).eval] \(testCase.description): input: '\(testCase.input)', got '\(result)', expected '\(expectedOutput)'",
            sourceLocation: testCase.sourceLocation
          )
        }
        catch {
          #expect(
            Bool(false),
            "[\(mode).eval] unexpected error: \(error), input: '\(testCase.input)', expected '\(expectedOutput)'",
            sourceLocation: testCase.sourceLocation
          )
        }
      }
    }
  }
}
