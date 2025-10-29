import Foundation

/// Validates the Swift package environment.
///
/// This class provides functionality to verify that the current directory
/// contains a valid Swift package before attempting to generate documentation.
public struct PackageValidator {
  // MARK: - Nested Types

  // MARK: - Errors

  /// Errors that can occur during package validation.
  public enum ValidationError: LocalizedError {
    case packageSwiftNotFound

    // MARK: - Computed Properties

    public var errorDescription: String? {
      switch self {
        case .packageSwiftNotFound:
          """
          ❌ Error: Package.swift not found in current directory
             Please run this script from the root of a Swift package
          """
      }
    }
  }

  // MARK: - Lifecycle

  /// Initializes a new PackageValidator.
  public init() {}

  // MARK: - Functions

  /// Validates that Package.swift exists in the current directory.
  ///
  /// - Throws: `ValidationError.packageSwiftNotFound` if Package.swift is not found.
  public func validate() throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: "./Package.swift") else {
      throw ValidationError.packageSwiftNotFound
    }
  }
}
