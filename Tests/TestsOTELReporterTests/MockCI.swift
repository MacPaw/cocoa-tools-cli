import CI
import ENV
import Foundation

/// A CI that reports exactly the metadata a test configures it with.
struct MockCI: CIInterface {
  let type: CIType = CIType(name: "Mock CI")
  let capabilities: CI.Capabilities = CI.Capabilities(canExportSecrets: false)
  let env: any CIEnvInterface = MockCIEnvironment()

  var repository: CI.Repository = CI.Repository()
  var cicd: CI.CICD = CI.CICD()

  init(env: ENV) {}

  init(repository: CI.Repository = CI.Repository(), cicd: CI.CICD = CI.CICD()) {
    self.repository = repository
    self.cicd = cicd
  }

  static func validateAsCurrentCI(_ environment: ENV) -> Bool { true }
}

/// A CI environment that discards everything written to it.
struct MockCIEnvironment: CIEnvInterface {
  func setSecret(name: String, value: String, isOutput: Bool) throws {}
  func setVariable(name: String, value: String, isOutput: Bool) throws {}
}
