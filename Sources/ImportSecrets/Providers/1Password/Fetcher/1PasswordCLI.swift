import Foundation
import Shell

/// Protocol for interacting with the 1Password CLI tool.
/// This abstraction allows for testing and different implementations of 1Password integration.
public protocol OnePasswordCLIProtocol: Sendable {
  /// Retrieves specific fields from a 1Password item.
  /// - Parameters:
  ///   - account: Optional account shorthand, sign-in address, account ID, or user ID.
  ///   - vault: Optional vault name or ID. If nil, searches all accessible vaults.
  ///   - item: The item name or ID to retrieve fields from.
  ///   - labels: Array of field labels to retrieve from the item.
  /// - Returns: Dictionary mapping field labels to their values.
  /// - Throws: CLI errors if the operation fails (authentication, network, item not found, etc.).
  func getItemFields(account: String?, vault: String?, item: String, labels: [String]) throws -> [String: String]
}

extension Shell {
  /// 1Password CLI wrapper implementation.
  /// This provides access to the 1Password command-line tool for retrieving secrets.
  public struct OnePassword {
    /// The URL to the 1Password CLI executable.
    let cliURL: URL
  }
}

extension Shell.OnePassword {
  /// Creates a new 1Password CLI wrapper.
  /// - Parameter cliURL: Optional path to the CLI executable. If nil, searches for 'op' in PATH or via mise.
  /// - Throws: Shell errors if the CLI executable cannot be found.
  public init(cliURL: URL? = .none) throws {
    try self.init(
      cliURL: cliURL ?? ((try? Shell.which(cliToolName: "op")) ?? (try Shell.Mise().which(cliToolName: "op")))
    )
  }

  /// Runs the 1Password CLI with the specified arguments.
  /// - Parameter arguments: Command line arguments to pass to the CLI.
  /// - Returns: The raw output data from the CLI command.
  /// - Throws: Shell errors if the command fails.
  private func run(arguments: [String]) throws -> Data { try Shell.run(executableURL: cliURL, arguments: arguments) }

  /// Retrieves specific fields from a 1Password item using the CLI.
  /// - Parameters:
  ///   - account: Optional account shorthand, sign-in address, account ID, or user ID.
  ///   - vault: Optional vault name or ID. If nil, searches all accessible vaults.
  ///   - item: The item name or ID to retrieve fields from.
  ///   - labels: Array of field labels to retrieve from the item.
  /// - Returns: Array of field structures containing labels and values.
  /// - Throws: CLI errors if the operation fails (authentication, network, item not found, etc.).
  func getItemFields(account: String?, vault: String?, item: String, labels: [String]) throws -> [Shell.OnePassword.Item
    .Field]
  {
    let arguments: [[String]] = [
      // Command
      ["item"],
      // Subcommand
      ["get", item],
      // Flags
      // Account
      account.map { ["--account", $0] },
      // Vault
      vault.map { ["--vault", $0] },
      // Fields
      ["--fields", labels.map { "label=\($0)" }.joined(separator: ",")],
      // Output format
      ["--format", "json"],
    ]
    .compactMap(\.self)

    let jsonData: Data = try run(arguments: arguments.flatMap(\.self))

    let fields: [Shell.OnePassword.Item.Field]
    do {
      if labels.count == 1 {
        let field: Shell.OnePassword.Item.Field = try JSONDecoder()
          .decode(Shell.OnePassword.Item.Field.self, from: jsonData)
        fields = [field]
      }
      else {
        fields = try JSONDecoder().decode([Shell.OnePassword.Item.Field].self, from: jsonData)
          .filter { labels.contains($0.label) }
      }
    }
    catch { throw error }

    return fields
  }
}

extension Shell.OnePassword {
  /// Represents a 1Password item as returned by the CLI.
  struct Item: Decodable {
    /// The title of the 1Password item.
    let title: String
    /// Array of fields contained in the item.
    let fields: [Field]
  }
}

extension Shell.OnePassword.Item {
  /// Represents a field within a 1Password item.
  struct Field: Decodable {
    /// The label/name of the field.
    let label: String
    /// The value stored in the field.
    let value: String
  }
}

extension Shell.OnePassword: OnePasswordCLIProtocol {
  public func getItemFields(account: String?, vault: String?, item: String, labels: [String]) throws -> [String: String]
  {
    let fields: [Shell.OnePassword.Item.Field] = try getItemFields(
      account: account,
      vault: vault,
      item: item,
      labels: labels
    )
    return fields.reduce(into: [String: String]()) { $0[$1.label] = $1.value }
  }
}
