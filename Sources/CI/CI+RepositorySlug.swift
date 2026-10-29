extension CI {
  /// Extracts the repository name from an `organization/repository` slug.
  ///
  /// CI providers report repositories either as a bare name or as an owner-qualified slug.
  /// Only the component after the last `/` is the repository name.
  ///
  /// - Parameter slug: A repository slug, with or without an organization component.
  /// - Returns: The repository name without its organization component.
  static func repositoryName(fromSlug slug: String) -> String {
    guard let separatorIndex = slug.lastIndex(of: "/") else { return slug }
    return String(slug[slug.index(after: separatorIndex)...])
  }
}
