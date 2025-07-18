import Foundation

extension URL {
  /// Returns the path component of the URL, removing any percent-encoding.
  ///
  /// - Note: Shortcut to `path(percentEncoded: false)`
  public var filePath: String { path(percentEncoded: false) }
}
