/// Represents a unique Source item.
///
/// There could be several secrets in the config file, but they can share the same item, but fetch different keys.
///
/// This protocol is to ensure we don't fetch the same item from the provider twice.
public protocol SecretSourceItemProtocol: Sendable, Equatable, Hashable {}
