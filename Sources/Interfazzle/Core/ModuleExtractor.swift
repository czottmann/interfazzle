import Foundation

/// Extracts public module names from a Swift package.
///
/// This class provides functionality to query a Swift package and discover
/// which modules are exposed as public products that should be documented.
/// It now uses a centralized PackageInfoProvider to avoid duplicate process spawns.
public struct ModuleExtractor {
  // MARK: - Nested Types

  /// Errors that can occur during module extraction.
  public enum ExtractionError: LocalizedError {
    case providerError(String)

    // MARK: - Computed Properties

    public var errorDescription: String? {
      switch self {
        case let .providerError(message):
          "Package provider error: \(message)"
      }
    }
  }

  // MARK: - Properties

  /// Centralized provider for package information with caching.
  private let packageInfoProvider: PackageInfoProvider

  // MARK: - Lifecycle

  /// Initializes a new ModuleExtractor with a package info provider.
  ///
  /// - Parameter packageInfoProvider: Centralized provider for package information.
  public init(packageInfoProvider: PackageInfoProvider = PackageInfoProvider()) {
    self.packageInfoProvider = packageInfoProvider
  }

  // MARK: - Functions

  /// Extracts public module names from the Swift package description.
  ///
  /// This function uses the centralized PackageInfoProvider to get the package
  /// information and extracts the target names from all products. This eliminates
  /// duplicate process spawns and provides caching for improved performance.
  ///
  /// - Returns: An array of module names that are exposed as products in the package.
  /// - Throws: `ExtractionError` if the package provider fails.
  public func extractPublicModules() throws -> [String] {
    do {
      return try packageInfoProvider.extractPublicModules()
    }
    catch let error as PackageInfoProvider.ProviderError {
      throw ExtractionError.providerError(error.localizedDescription)
    }
    catch {
      throw ExtractionError.providerError(error.localizedDescription)
    }
  }
}
