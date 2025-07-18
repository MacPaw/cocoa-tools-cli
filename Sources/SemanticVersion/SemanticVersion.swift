//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2018-2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

/// A version according to the semantic versioning specification.
///
/// A package version consists of three integers separated by periods, for example `1.0.0`. It must conform to the semantic versioning standard in order to ensure
/// that your package behaves in a predictable manner once developers update their
/// package dependency to a newer version. To achieve predictability, the semantic versioning specification proposes a set of rules and
/// requirements that dictate how version numbers are assigned and incremented. To learn more about the semantic versioning specification, visit
/// [Semantic Versioning 2.0.0](https://semver.org).
///
/// - term The major version: The first digit of a version, or _major version_,
/// signifies breaking changes to the API that require updates to existing
/// clients. For example, the semantic versioning specification considers
/// renaming an existing type, removing a method, or changing a method's
/// signature breaking changes. This also includes any backward-incompatible bug
/// fixes or behavioral changes of the existing API.
///
/// - term The minor version:
/// Update the second digit of a version, or _minor version_, if you add
/// functionality in a backward-compatible manner. For example, the semantic
/// versioning specification considers adding a new method or type without
/// changing any other API to be backward-compatible.
///
/// - term The patch version:
/// Increase the third digit of a version, or _patch version_, if you're making
/// a backward-compatible bug fix. This allows clients to benefit from bugfixes
/// to your package without incurring any maintenance burden.
public struct SemanticVersion: Sendable {
  /// The major version according to the semantic versioning standard.
  public let major: Int

  /// The minor version according to the semantic versioning standard.
  public let minor: Int

  /// The patch version according to the semantic versioning standard.
  public let patch: Int

  /// The pre-release identifier according to the semantic versioning standard, such as `-beta.1`.
  public let prereleaseIdentifiers: [String]

  /// The build metadata of this version according to the semantic versioning standard, such as a commit hash.
  public let buildMetadataIdentifiers: [String]

  /// Initializes a version struct with the provided components of a semantic version.
  ///
  /// - Parameters:
  ///   - major: The major version number.
  ///   - minor: The minor version number.
  ///   - patch: The patch version number.
  ///   - prereleaseIdentifiers: The pre-release identifier.
  ///   - buildMetadataIdentifiers: Build metadata that identifies a build.
  ///
  /// - Precondition: `major >= 0 && minor >= 0 && patch >= 0`.
  /// - Precondition: `prereleaseIdentifiers` can contain only ASCII alpha-numeric characters and "-".
  /// - Precondition: `buildIdentifiers` can contain only ASCII alpha-numeric characters and "-".
  public init(
    _ major: Int,
    _ minor: Int = 0,
    _ patch: Int = 0,
    prereleaseIdentifiers: [String] = [],
    buildMetadataIdentifiers: [String] = []
  ) {
    precondition(major >= 0 && minor >= 0 && patch >= 0, "Negative versioning is invalid.")
    precondition(
      prereleaseIdentifiers.allSatisfy { $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") } },
      #"Pre-release identifiers can contain only ASCII alpha-numeric characters and "-"."#
    )
    precondition(
      buildMetadataIdentifiers.allSatisfy { $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") } },
      #"Build metadata identifiers can contain only ASCII alpha-numeric characters and "-"."#
    )
    self.major = major
    self.minor = minor
    self.patch = patch
    self.prereleaseIdentifiers = prereleaseIdentifiers
    self.buildMetadataIdentifiers = buildMetadataIdentifiers
  }
}

extension SemanticVersion: Comparable {
  // Although `Comparable` inherits from `Equatable`, it does not provide a new default implementation of `==`, but instead uses `Equatable`'s default synthesised implementation. The compiler-synthesised `==`` is composed of [member-wise comparisons](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0185-synthesize-equatable-hashable.md#implementation-details), which leads to a false `false` when 2 semantic versions differ by only their build metadata identifiers, contradicting SemVer 2.0.0's [comparison rules](https://semver.org/#spec-item-10).

  /// Returns a Boolean value indicating whether two values are equal.
  ///
  /// Equality is the inverse of inequality. For any values `a` and `b`, `a ==
  /// b` implies that `a != b` is `false`.
  ///
  /// - Parameters:
  ///   - lhs: A value to compare.
  ///   - rhs: Another value to compare.
  ///
  /// - Returns: A boolean value indicating the result of the equality test.
  @inlinable
  public static func == (lhs: Self, rhs: Self) -> Bool { !(lhs < rhs) && !(lhs > rhs) }

  /// Returns a Boolean value indicating whether the value of the first
  /// argument is less than that of the second argument.
  ///
  /// The precedence is determined according to rules described in the [Semantic Versioning 2.0.0](https://semver.org) standard, paragraph 11.
  ///
  /// - Parameters:
  ///   - lhs: A value to compare.
  ///   - rhs: Another value to compare.
  public static func < (lhs: Self, rhs: Self) -> Bool {
    let lhsComparators = [lhs.major, lhs.minor, lhs.patch]
    let rhsComparators = [rhs.major, rhs.minor, rhs.patch]

    if lhsComparators != rhsComparators { return lhsComparators.lexicographicallyPrecedes(rhsComparators) }

    guard lhs.prereleaseIdentifiers.count > 0 else {
      return false  // Non-prerelease lhs >= potentially prerelease rhs
    }

    guard rhs.prereleaseIdentifiers.count > 0 else {
      return true  // Prerelease lhs < non-prerelease rhs
    }

    for (lhsPrereleaseIdentifier, rhsPrereleaseIdentifier) in zip(lhs.prereleaseIdentifiers, rhs.prereleaseIdentifiers)
    {
      if lhsPrereleaseIdentifier == rhsPrereleaseIdentifier { continue }

      // Check if either of the 2 pre-release identifiers is numeric.
      let lhsNumericPrereleaseIdentifier = Int(lhsPrereleaseIdentifier)
      let rhsNumericPrereleaseIdentifier = Int(rhsPrereleaseIdentifier)

      if let lhsNumericPrereleaseIdentifier, let rhsNumericPrereleaseIdentifier = rhsNumericPrereleaseIdentifier {
        return lhsNumericPrereleaseIdentifier < rhsNumericPrereleaseIdentifier
      }
      else if lhsNumericPrereleaseIdentifier != nil {
        return true  // numeric pre-release < non-numeric pre-release
      }
      else if rhsNumericPrereleaseIdentifier != nil {
        return false  // non-numeric pre-release > numeric pre-release
      }
      else {
        return lhsPrereleaseIdentifier < rhsPrereleaseIdentifier
      }
    }

    return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
  }
}

extension SemanticVersion: CustomStringConvertible {
  /// A textual description of the version object.
  public var description: String {
    var base = "\(major).\(minor).\(patch)"
    if !prereleaseIdentifiers.isEmpty { base += "-" + prereleaseIdentifiers.joined(separator: ".") }
    if !buildMetadataIdentifiers.isEmpty { base += "+" + buildMetadataIdentifiers.joined(separator: ".") }
    return base
  }
}

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2018-2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension SemanticVersion: ExpressibleByStringLiteral {
  /// Initializes a version struct with the provided string literal.
  ///
  /// - Parameter value: A string literal to use for creating a new version struct.
  public init(stringLiteral value: String) {
    if let version: Self = Self(value) {
      self = version
    }
    else {
      // If version can't be initialized using the string literal, report
      // the error and initialize with a dummy value. This is done to
      // report error to the invoking tool (like swift build) gracefully
      // rather than just crashing.
      print("Error: Invalid semantic version string '\(value)'")
      self.init(0, 0, 0)
    }
  }

  /// Initializes a version struct with the provided extended grapheme cluster.
  ///
  /// - Parameter value: An extended grapheme cluster to use for creating a new
  ///   version struct.
  public init(extendedGraphemeClusterLiteral value: String) { self.init(stringLiteral: value) }

  /// Initializes a version struct with the provided Unicode string.
  ///
  /// - Parameter value: A Unicode string to use for creating a new version struct.
  public init(unicodeScalarLiteral value: String) { self.init(stringLiteral: value) }
}

extension SemanticVersion {}
extension SemanticVersion: LosslessStringConvertible {
  /// Initializes a version struct with the provided version string.
  /// - Parameter versionString: A version string to use for creating a new version struct.
  public init?(_ versionString: String) {
    guard let version: Self = try? Self.build(versionString) else { return nil }
    self = version
  }

  public enum ParseError: Swift.Error {
    case invalidStringVersionFormat(invalidCharacters: String)
    case invalidMajorVersion(String)
    case invalidMinorVersion(String)
    case invalidPatchVersion(String)
    case invalidPrereleaseIdentifiers([String])
    case invalidBuildIdentifiers([String])

    public var errorDescription: String {
      switch self {
      case .invalidStringVersionFormat(let invalidCharacters):
        return
          "Invalid string version format. String must contain only ASCII alphanumerical characters and '-' except for '.' and '+' as delimiters. Invalid characters: '\(invalidCharacters)'"
      case .invalidMajorVersion(let string): return "Major version must be a non-negative integer, but got '\(string)'."
      case .invalidMinorVersion(let string): return "Minor version must be a non-negative integer, but got '\(string)'."
      case .invalidPatchVersion(let string): return "Patch version must be a non-negative integer, but got '\(string)'."
      case .invalidPrereleaseIdentifiers(let strings):
        return
          "Prerelease identifiers must consist of ASCII alphanumerical characters except for '-'. Invalid identifiers: '\(strings)'"
      case .invalidBuildIdentifiers(let strings):
        return
          "Build identifiers must consist of ASCII alphanumerical characters except for '-'. Invalid identifiers: '\(strings)'"
      }
    }
  }

  /// Initializes a version struct with the provided version string.
  /// - Parameter versionString: A version string to use for creating a new version struct.
  public static func build(_ versionString: String) throws(ParseError) -> Self {
    // SemVer 2.0.0 allows only ASCII alphanumerical characters and "-" in the version string, except for "." and "+" as delimiters. ("-" is used as a delimiter between the version core and pre-release identifiers, but it's allowed within pre-release and metadata identifiers as well.)
    // Alphanumerics check will come later, after each identifier is split out (i.e. after the delimiters are removed).
    guard versionString.allSatisfy(\.isASCII) else {
      let invalidChars = versionString.filter { !$0.isASCII }
      throw ParseError.invalidStringVersionFormat(invalidCharacters: invalidChars)
    }

    let metadataDelimiterIndex = versionString.firstIndex(of: "+")
    // SemVer 2.0.0 requires that pre-release identifiers come before build metadata identifiers
    let prereleaseDelimiterIndex = versionString[..<(metadataDelimiterIndex ?? versionString.endIndex)]
      .firstIndex(of: "-")

    let versionCore = versionString[..<(prereleaseDelimiterIndex ?? metadataDelimiterIndex ?? versionString.endIndex)]
    var versionCoreIdentifiers: [String] = versionCore.split(separator: ".", omittingEmptySubsequences: false)
      .map(String.init)
    while versionCoreIdentifiers.count < 3 { versionCoreIdentifiers.append("0") }

    let majorVersionString = versionCoreIdentifiers[0]
    guard let majorVersion = Int(majorVersionString), majorVersion >= 0 else {
      throw ParseError.invalidMajorVersion(majorVersionString)
    }

    let minorVersionString = versionCoreIdentifiers[1]
    guard let minorVersion = Int(minorVersionString), minorVersion >= 0 else {
      throw ParseError.invalidMajorVersion(minorVersionString)
    }

    let patchVersionString = versionCoreIdentifiers[2]
    guard let patchVersion = Int(patchVersionString), patchVersion >= 0 else {
      throw ParseError.invalidMajorVersion(patchVersionString)
    }

    var prereleaseIdentifiers: [String] = []
    if let prereleaseDelimiterIndex {
      let prereleaseStartIndex = versionString.index(after: prereleaseDelimiterIndex)
      let parsedPrereleaseIdentifiers = versionString[
        prereleaseStartIndex..<(metadataDelimiterIndex ?? versionString.endIndex)
      ]
      .split(separator: ".", omittingEmptySubsequences: false)
      let prereleaseIdentifierValidation: (Substring.SubSequence) -> Bool = { prereleaseIdentifier in
        prereleaseIdentifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
      }
      guard parsedPrereleaseIdentifiers.allSatisfy(prereleaseIdentifierValidation) else {
        let invalidPrereleaseIdentifiers = parsedPrereleaseIdentifiers.filter { !prereleaseIdentifierValidation($0) }
          .map(String.init)
        throw ParseError.invalidPrereleaseIdentifiers(invalidPrereleaseIdentifiers)
      }
      prereleaseIdentifiers = parsedPrereleaseIdentifiers.map { String($0) }
    }

    var buildMetadataIdentifiers: [String] = []
    if let metadataDelimiterIndex {
      let metadataStartIndex = versionString.index(after: metadataDelimiterIndex)
      let parsedBuildMetadataIdentifiers = versionString[metadataStartIndex...]
        .split(separator: ".", omittingEmptySubsequences: false)
      let buildMetadataIdentifierValidation: (Substring.SubSequence) -> Bool = { buildIdentifier in
        buildIdentifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
      }
      guard parsedBuildMetadataIdentifiers.allSatisfy(buildMetadataIdentifierValidation) else {
        let invalidBuildIdentifiers = parsedBuildMetadataIdentifiers.filter { !buildMetadataIdentifierValidation($0) }
          .map(String.init)
        throw ParseError.invalidBuildIdentifiers(invalidBuildIdentifiers)
      }
      buildMetadataIdentifiers = parsedBuildMetadataIdentifiers.map { String($0) }
    }

    let semanticVersion: Self = Self.init(
      majorVersion,
      minorVersion,
      patchVersion,
      prereleaseIdentifiers: prereleaseIdentifiers,
      buildMetadataIdentifiers: buildMetadataIdentifiers
    )

    return semanticVersion
  }
}

extension SemanticVersion: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) { self.init(value, 0, 0) }
}

extension SemanticVersion: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) { self.init(stringLiteral: String(value)) }
}

extension SemanticVersion: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let versionString: String
    do { versionString = try container.decode(String.self) }
    catch {
      do { versionString = try String(container.decode(Int.self)) }
      catch {
        do { versionString = try String(container.decode(Double.self)) }
        catch {
          throw DecodingError.typeMismatch(
            SemanticVersion.self,
            DecodingError.Context(
              codingPath: decoder.codingPath,
              debugDescription: "Expected to decode String, Int or Double"
            )
          )
        }
      }
    }

    do { self = try SemanticVersion.build(versionString) }
    catch {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Could not parse \(versionString) as SemanticVersion: \(error.errorDescription)"
      )
    }
  }
}

extension SemanticVersion: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}

extension SemanticVersion {
  public var version: String? {
    guard let buildIndex = buildMetadataIdentifiers.firstIndex(of: "build"),
      buildIndex < buildMetadataIdentifiers.endIndex
    else { return .none }

    let buildValueIndex = buildMetadataIdentifiers.index(after: buildIndex)

    return buildMetadataIdentifiers[buildValueIndex]
  }
}
