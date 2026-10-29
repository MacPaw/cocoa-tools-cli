import Foundation
import Testing

@testable import CI
@testable import ENV

@Suite("GitHub Actions metadata")
struct GitHubActionsMetadataTests {
  /// The variables GitHub Actions sets for a typical workflow run.
  private static let variables: [String: String] = [
    "GITHUB_ACTION": "run",
    "GITHUB_REPOSITORY_OWNER": "MacPaw",
    "GITHUB_REPOSITORY": "MacPaw/mpct",
    "GITHUB_WORKFLOW": "CI",
    "GITHUB_JOB": "test",
    "GITHUB_RUN_ID": "42",
    "GITHUB_RUN_NUMBER": "7",
    "GITHUB_SERVER_URL": "https://github.com",
  ]

  /// Builds the CI under test.
  ///
  /// - Parameter overrides: Variables merged over the defaults; an empty value unsets one.
  /// - Returns: The CI.
  private func makeSUT(overrides: [String: String] = [:]) -> CI.GitHubActions {
    CI.GitHubActions(env: ENV(variables: Self.variables.merging(overrides) { _, new in new }))
  }

  @Test("repository readsOwnerAndNameFromBuiltInVariables")
  func test_repository_readsOwnerAndNameFromBuiltInVariables() {
    // GIVEN — a run with only GitHub's own variables set
    let sut = makeSUT()

    // WHEN
    let repository = sut.repository

    // THEN — the owner is stripped from the slug, leaving the bare repository name
    #expect(repository.organizationName == "MacPaw")
    #expect(repository.repositoryName == "mpct")
    #expect(repository.provider == "github")
  }

  @Test("repository prefersTemplateVariablesOverBuiltInOnes")
  func test_repository_prefersTemplateVariablesOverBuiltInOnes() {
    // GIVEN — the cocoa-ci-templates variables are also set
    let sut = makeSUT(overrides: ["ORGANIZATION_NAME": "macpaw-templates", "REPOSITORY_NAME": "renamed"])

    // WHEN
    let repository = sut.repository

    // THEN — labels match the CAS metrics, which read the same variables
    #expect(repository.organizationName == "macpaw-templates")
    #expect(repository.repositoryName == "renamed")
  }

  @Test("repository ignoresEmptyTemplateVariables")
  func test_repository_ignoresEmptyTemplateVariables() {
    // GIVEN — declared-but-empty variables, which CI systems export routinely
    let sut = makeSUT(overrides: ["ORGANIZATION_NAME": "", "REPOSITORY_NAME": ""])

    // WHEN
    let repository = sut.repository

    // THEN — an empty override does not blank out the built-in value
    #expect(repository.organizationName == "MacPaw")
    #expect(repository.repositoryName == "mpct")
  }

  @Test("cicd readsPipelineAndRunMetadata")
  func test_cicd_readsPipelineAndRunMetadata() {
    // GIVEN
    let sut = makeSUT()

    // WHEN
    let cicd = sut.cicd

    // THEN
    #expect(cicd.pipelineName == "CI")
    #expect(cicd.run.id == "42")
    #expect(cicd.run.number == "7")
    #expect(cicd.run.taskName == "test")
    #expect(cicd.run.stageName == nil)
    #expect(cicd.run.url?.absoluteString == "https://github.com/MacPaw/mpct/actions/runs/42")
  }

  @Test("cicd prefersJobNameOverJobID")
  func test_cicd_prefersJobNameOverJobID() {
    // GIVEN — a matrix leg, whose GITHUB_JOB every other leg shares
    let sut = makeSUT(overrides: ["JOB_NAME": "test-macos"])

    // WHEN / THEN
    #expect(sut.cicd.run.taskName == "test-macos")
  }

  @Test("cicd omitsRunURLWhenServerIsUnknown")
  func test_cicd_omitsRunURLWhenServerIsUnknown() {
    // GIVEN — a run without the server URL variable
    let sut = makeSUT(overrides: ["GITHUB_SERVER_URL": ""])

    // WHEN / THEN — no URL is better than a guessed one
    #expect(sut.cicd.run.url == nil)
  }
}

@Suite("Azure Pipelines metadata")
struct AzurePipelinesMetadataTests {
  /// The variables Azure Pipelines sets for a typical build.
  private static let variables: [String: String] = [
    "SYSTEM_COLLECTIONURI": "https://dev.azure.com/macpaw/",
    "SYSTEM_TEAMPROJECT": "Cocoa",
    "BUILD_REPOSITORY_NAME": "MacPaw/mpct",
    "BUILD_REPOSITORY_PROVIDER": "GitHub",
    "BUILD_DEFINITIONNAME": "mpct CI",
    "BUILD_BUILDID": "1234",
    "BUILD_BUILDNUMBER": "20260914.1",
    "SYSTEM_JOBDISPLAYNAME": "Test",
    "SYSTEM_STAGEDISPLAYNAME": "Build",
  ]

  /// Builds the CI under test.
  ///
  /// - Parameter overrides: Variables merged over the defaults; an empty value unsets one.
  /// - Returns: The CI.
  private func makeSUT(overrides: [String: String] = [:]) -> CI.AzurePipelines {
    CI.AzurePipelines(env: ENV(variables: Self.variables.merging(overrides) { _, new in new }))
  }

  @Test("repository derivesOrganizationFromCollectionURL")
  func test_repository_derivesOrganizationFromCollectionURL() {
    // GIVEN — a build with only Azure's own variables set
    let sut = makeSUT()

    // WHEN
    let repository = sut.repository

    // THEN — the organization is the last path component of the collection URL
    #expect(repository.organizationName == "macpaw")
    #expect(repository.repositoryName == "mpct")
    #expect(repository.provider == "github")
  }

  @Test("repository prefersTemplateVariablesOverBuiltInOnes")
  func test_repository_prefersTemplateVariablesOverBuiltInOnes() {
    // GIVEN — the cocoa-ci-templates variables are set alongside Azure's
    let sut = makeSUT(overrides: ["ORGANIZATION_NAME": "MacPaw", "REPOSITORY_NAME": "mpct"])

    // WHEN
    let repository = sut.repository

    // THEN — the templates win, so labels join with the CAS metrics
    #expect(repository.organizationName == "MacPaw")
    #expect(repository.repositoryName == "mpct")
  }

  @Test("repository omitsOrganizationWhenCollectionURLIsMissing")
  func test_repository_omitsOrganizationWhenCollectionURLIsMissing() {
    // GIVEN — neither the collection URL nor the template variable
    let sut = makeSUT(overrides: ["SYSTEM_COLLECTIONURI": ""])

    // WHEN / THEN
    #expect(sut.repository.organizationName == nil)
  }

  @Test("cicd readsPipelineAndRunMetadata")
  func test_cicd_readsPipelineAndRunMetadata() {
    // GIVEN
    let sut = makeSUT()

    // WHEN
    let cicd = sut.cicd

    // THEN — including the stage, which has no OpenTelemetry attribute but matches the CAS labels
    #expect(cicd.pipelineName == "mpct CI")
    #expect(cicd.run.id == "1234")
    #expect(cicd.run.number == "20260914.1")
    #expect(cicd.run.taskName == "Test")
    #expect(cicd.run.stageName == "Build")
    #expect(
      cicd.run.url?.absoluteString == "https://dev.azure.com/macpaw/Cocoa/_build/results?buildId=1234"
    )
  }
}

@Suite("Local CI metadata")
struct LocalCIMetadataTests {
  @Test("repository reportsNothingOnLocalMachine")
  func test_repository_reportsNothingOnLocalMachine() {
    // GIVEN — a developer's machine, where there is no pipeline to describe
    let sut = CI.Local(env: ENV(variables: [:]))

    // WHEN / THEN — empty metadata, so every attribute is omitted rather than invented
    #expect(sut.repository == CI.Repository())
    #expect(sut.cicd == CI.CICD())
  }
}
