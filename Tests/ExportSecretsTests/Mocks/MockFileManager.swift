import Foundation

@testable import ExportSecrets

final class MockFileManager: FileManagerProtocol, @unchecked Sendable {
  var createdFiles: [(path: String, contents: Data?)] = []
  var shouldSucceed: Bool = true

  func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool {
    createdFiles.append((path: path, contents: data))
    return shouldSucceed
  }

  func contents(atPath path: String) -> Data? { createdFiles.first { $0.path == path }?.contents }
}
