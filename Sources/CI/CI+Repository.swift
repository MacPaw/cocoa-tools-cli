/// Source control repository metadata, as reported by the current CI.
extension CI {
  /// Metadata about the source control repository the current run builds.
  ///
  /// All properties are optional: a CI that cannot report a value leaves it `nil`,
  /// and consumers are expected to omit it rather than substitute a placeholder.
  public struct Repository {
    /// Name of the organization, owner, or user the repository belongs to.
    public var organizationName: String?
    /// Name of the repository, without the organization component.
    public var repositoryName: String?
    /// Name of the version control provider hosting the repository, such as `github` or `gitlab`.
    public var provider: String?

    /// Initializes repository metadata.
    ///
    /// - Parameters:
    ///   - organizationName: Name of the organization, owner, or user the repository belongs to.
    ///   - repositoryName: Name of the repository, without the organization component.
    ///   - provider: Name of the version control provider hosting the repository.
    public init(
      organizationName: String? = .none,
      repositoryName: String? = .none,
      provider: String? = .none,
    ) {
      self.organizationName = organizationName
      self.repositoryName = repositoryName
      self.provider = provider
    }
  }
}

extension CI.Repository: Sendable {}
extension CI.Repository: Equatable {}
