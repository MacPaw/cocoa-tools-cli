import Foundation
import Testing
@testable import HashiCorpVaultReader

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("Error Tests")
struct ErrorTests {

  // MARK: - HashiCorpVaultReader Error Tests

  @Test("Error invalidURL case")
  func test_error_invalidURL() {
    // GIVEN: URL and error message
    let url = URL(string: "https://vault.example.com")!
    let message = "Invalid URL format"

    // WHEN: Creating invalidURL error
    let sut = HashiCorpVaultReader.Error.invalidURL(url: url, message: message)

    // THEN: Error contains correct information
    switch sut {
    case .invalidURL(let errorURL, let errorMessage):
      #expect(errorURL == url)
      #expect(errorMessage == message)
    default:
      #expect(Bool(false), "Expected invalidURL case")
    }
  }

  @Test("Error urlIsNotSet case")
  func test_error_urlIsNotSet() {
    // GIVEN: urlIsNotSet error

    // WHEN: Creating urlIsNotSet error
    let sut = HashiCorpVaultReader.Error.urlIsNotSet

    // THEN: Error is correct case
    switch sut {
    case .urlIsNotSet:
      #expect(Bool(true), "Expected urlIsNotSet case")
    default:
      #expect(Bool(false), "Expected urlIsNotSet case")
    }
  }

  @Test("Error noSecretsFetched case")
  func test_error_noSecretsFetched() {
    // GIVEN: Secret name and item
    let secretName = "DATABASE_PASSWORD"
    let item = HashiCorpVaultReader.Element(
      keyValue: .init(
        secretMountPath: "secret",
        path: "myapp/database",
        version: 1,
        key: "password"
      )
    )

    // WHEN: Creating noSecretsFetched error
    let sut = HashiCorpVaultReader.Error.noSecretsFetched(secretName: secretName, item: item)

    // THEN: Error contains correct information
    switch sut {
    case .noSecretsFetched(let errorSecretName, let errorItem):
      #expect(errorSecretName == secretName)
      #expect(errorItem.keyValue?.secretMountPath == "secret")
      #expect(errorItem.keyValue?.path == "myapp/database")
    default:
      #expect(Bool(false), "Expected noSecretsFetched case")
    }
  }

  @Test("Error noSecretValueForItemKey case")
  func test_error_noSecretValueForItemKey() {
    // GIVEN: Secret name, item, and key
    let secretName = "DATABASE_PASSWORD"
    let key = "password"
    let item = HashiCorpVaultReader.Element(
      keyValue: .init(
        secretMountPath: "secret",
        path: "myapp/database",
        version: 1,
        key: key
      )
    )

    // WHEN: Creating noSecretValueForItemKey error
    let sut = HashiCorpVaultReader.Error.noSecretValueForItemKey(
      secretName: secretName,
      item: item,
      key: key
    )

    // THEN: Error contains correct information
    switch sut {
    case .noSecretValueForItemKey(let errorSecretName, let errorItem, let errorKey):
      #expect(errorSecretName == secretName)
      #expect(errorKey == key)
      #expect(errorItem.keyValue?.key == key)
    default:
      #expect(Bool(false), "Expected noSecretValueForItemKey case")
    }
  }

  @Test("Error tooManyEngineConfigs case")
  func test_error_tooManyEngineConfigs() {
    // GIVEN: tooManyEngineConfigs error

    // WHEN: Creating tooManyEngineConfigs error
    let sut = HashiCorpVaultReader.Error.tooManyEngineConfigs

    // THEN: Error is correct case
    switch sut {
    case .tooManyEngineConfigs:
      #expect(Bool(true), "Expected tooManyEngineConfigs case")
    default:
      #expect(Bool(false), "Expected tooManyEngineConfigs case")
    }
  }

  @Test("Error noConfigsForItem case")
  func test_error_noConfigsForItem() {
    // GIVEN: noConfigsForItem error

    // WHEN: Creating noConfigsForItem error
    let sut = HashiCorpVaultReader.Error.noConfigsForItem

    // THEN: Error is correct case
    switch sut {
    case .noConfigsForItem:
      #expect(Bool(true), "Expected noConfigsForItem case")
    default:
      #expect(Bool(false), "Expected noConfigsForItem case")
    }
  }

  @Test("Error appRoleAuthenticationCredentialsAreNotSet case")
  func test_error_appRoleAuthenticationCredentialsAreNotSet() {
    // GIVEN: appRoleAuthenticationCredentialsAreNotSet error

    // WHEN: Creating appRoleAuthenticationCredentialsAreNotSet error
    let sut = HashiCorpVaultReader.Error.appRoleAuthenticationCredentialsAreNotSet

    // THEN: Error is correct case
    switch sut {
    case .appRoleAuthenticationCredentialsAreNotSet:
      #expect(Bool(true), "Expected appRoleAuthenticationCredentialsAreNotSet case")
    default:
      #expect(Bool(false), "Expected appRoleAuthenticationCredentialsAreNotSet case")
    }
  }

  @Test("Error tokenAuthenticationCredentialsIsNotSet case")
  func test_error_tokenAuthenticationCredentialsIsNotSet() {
    // GIVEN: tokenAuthenticationCredentialsIsNotSet error

    // WHEN: Creating tokenAuthenticationCredentialsIsNotSet error
    let sut = HashiCorpVaultReader.Error.tokenAuthenticationCredentialsIsNotSet

    // THEN: Error is correct case
    switch sut {
    case .tokenAuthenticationCredentialsIsNotSet:
      #expect(Bool(true), "Expected tokenAuthenticationCredentialsIsNotSet case")
    default:
      #expect(Bool(false), "Expected tokenAuthenticationCredentialsIsNotSet case")
    }
  }

  @Test("Error cantGetTokenFromAppRoleAuthenticationResponse case")
  func test_error_cantGetTokenFromAppRoleAuthenticationResponse() {
    // GIVEN: cantGetTokenFromAppRoleAuthenticationResponse error

    // WHEN: Creating cantGetTokenFromAppRoleAuthenticationResponse error
    let sut = HashiCorpVaultReader.Error.cantGetTokenFromAppRoleAuthenticationResponse

    // THEN: Error is correct case
    switch sut {
    case .cantGetTokenFromAppRoleAuthenticationResponse:
      #expect(Bool(true), "Expected cantGetTokenFromAppRoleAuthenticationResponse case")
    default:
      #expect(Bool(false), "Expected cantGetTokenFromAppRoleAuthenticationResponse case")
    }
  }

  // MARK: - HTTPError Tests

  @Test("HTTPError responseNotHTTP case")
  func test_httpError_responseNotHTTP() {
    // GIVEN: Non-HTTP URL response
    let response = URLResponse(
      url: URL(string: "https://vault.example.com")!,
      mimeType: nil,
      expectedContentLength: 0,
      textEncodingName: nil
    )

    // WHEN: Creating responseNotHTTP error
    let sut = HashiCorpVaultReader.HTTPError.responseNotHTTP(response)

    // THEN: Error contains correct response
    switch sut {
    case .responseNotHTTP(let errorResponse):
      #expect(errorResponse === response)
    default:
      #expect(Bool(false), "Expected responseNotHTTP case")
    }
  }

  @Test("HTTPError wrongStatusCode case")
  func test_httpError_wrongStatusCode() {
    // GIVEN: HTTP status code
    let statusCode = 404

    // WHEN: Creating wrongStatusCode error
    let sut = HashiCorpVaultReader.HTTPError.wrongStatusCode(statusCode)

    // THEN: Error contains correct status code
    switch sut {
    case .wrongStatusCode(let errorStatusCode):
      #expect(errorStatusCode == statusCode)
    default:
      #expect(Bool(false), "Expected wrongStatusCode case")
    }
  }

  // MARK: - Error Pattern Matching Tests

  @Test("Error pattern matching in do-catch")
  func test_error_patternMatchingInDoCatch() async {
    // GIVEN: Function that throws specific error
    func throwsTokenError() throws {
      throw HashiCorpVaultReader.Error.tokenAuthenticationCredentialsIsNotSet
    }

    // WHEN: Catching specific error
    var caughtCorrectError = false
    do {
      try throwsTokenError()
    } catch HashiCorpVaultReader.Error.tokenAuthenticationCredentialsIsNotSet {
      caughtCorrectError = true
    } catch {
      // Should not reach here
    }

    // THEN: Correct error was caught
    #expect(caughtCorrectError)
  }

  @Test("HTTPError pattern matching in do-catch")
  func test_httpError_patternMatchingInDoCatch() async {
    // GIVEN: Function that throws HTTP error
    func throwsHTTPError() throws {
      throw HashiCorpVaultReader.HTTPError.wrongStatusCode(401)
    }

    // WHEN: Catching specific HTTP error
    var caughtCorrectError = false
    var caughtStatusCode = 0
    do {
      try throwsHTTPError()
    } catch HashiCorpVaultReader.HTTPError.wrongStatusCode(let statusCode) {
      caughtCorrectError = true
      caughtStatusCode = statusCode
    } catch {
      // Should not reach here
    }

    // THEN: Correct error was caught with correct status code
    #expect(caughtCorrectError)
    #expect(caughtStatusCode == 401)
  }

  // MARK: - Error Equality Tests

  @Test("Error cases equality comparison")
  func test_error_casesEqualityComparison() {
    // GIVEN: Same error cases
    let error1 = HashiCorpVaultReader.Error.urlIsNotSet
    let error2 = HashiCorpVaultReader.Error.urlIsNotSet
    let error3 = HashiCorpVaultReader.Error.tooManyEngineConfigs

    // WHEN: Comparing errors
    let sameErrorsEqual = compareErrors(error1, error2)
    let differentErrorsEqual = compareErrors(error1, error3)

    // THEN: Same errors are considered equal, different are not
    #expect(sameErrorsEqual)
    #expect(!differentErrorsEqual)
  }

  @Test("Error with associated values equality")
  func test_error_withAssociatedValuesEquality() {
    // GIVEN: Errors with same associated values
    let url = URL(string: "https://vault.example.com")!
    let message = "Test message"
    let error1 = HashiCorpVaultReader.Error.invalidURL(url: url, message: message)
    let error2 = HashiCorpVaultReader.Error.invalidURL(url: url, message: message)
    let error3 = HashiCorpVaultReader.Error.invalidURL(url: url, message: "Different message")

    // WHEN: Comparing errors
    let sameErrorsEqual = compareErrors(error1, error2)
    let differentErrorsEqual = compareErrors(error1, error3)

    // THEN: Same errors with same values are equal, different values are not
    #expect(sameErrorsEqual)
    #expect(!differentErrorsEqual)
  }

  @Test("HTTPError cases equality comparison")
  func test_httpError_casesEqualityComparison() {
    // GIVEN: Same HTTP error cases
    let error1 = HashiCorpVaultReader.HTTPError.wrongStatusCode(404)
    let error2 = HashiCorpVaultReader.HTTPError.wrongStatusCode(404)
    let error3 = HashiCorpVaultReader.HTTPError.wrongStatusCode(500)

    // WHEN: Comparing HTTP errors
    let sameErrorsEqual = compareHTTPErrors(error1, error2)
    let differentErrorsEqual = compareHTTPErrors(error1, error3)

    // THEN: Same errors are equal, different are not
    #expect(sameErrorsEqual)
    #expect(!differentErrorsEqual)
  }

  // MARK: - Helper Methods

  private func compareErrors(_ error1: HashiCorpVaultReader.Error, _ error2: HashiCorpVaultReader.Error) -> Bool {
    switch (error1, error2) {
    case (.urlIsNotSet, .urlIsNotSet),
         (.tooManyEngineConfigs, .tooManyEngineConfigs),
         (.noConfigsForItem, .noConfigsForItem),
         (.appRoleAuthenticationCredentialsAreNotSet, .appRoleAuthenticationCredentialsAreNotSet),
         (.tokenAuthenticationCredentialsIsNotSet, .tokenAuthenticationCredentialsIsNotSet),
         (.cantGetTokenFromAppRoleAuthenticationResponse, .cantGetTokenFromAppRoleAuthenticationResponse):
      return true
    case (.invalidURL(let url1, let message1), .invalidURL(let url2, let message2)):
      return url1 == url2 && message1 == message2
    case (.noSecretsFetched(let name1, _), .noSecretsFetched(let name2, _)):
      return name1 == name2
    case (.noSecretValueForItemKey(let name1, _, let key1), .noSecretValueForItemKey(let name2, _, let key2)):
      return name1 == name2 && key1 == key2
    default:
      return false
    }
  }

  private func compareHTTPErrors(_ error1: HashiCorpVaultReader.HTTPError, _ error2: HashiCorpVaultReader.HTTPError) -> Bool {
    switch (error1, error2) {
    case (.wrongStatusCode(let code1), .wrongStatusCode(let code2)):
      return code1 == code2
    case (.responseNotHTTP(let response1), .responseNotHTTP(let response2)):
      return response1 === response2
    default:
      return false
    }
  }
}


