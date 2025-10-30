import Foundation

/// Loads package description and extracts target path information.
///
/// This class provides functionality to query a Swift package and discover
/// the file system locations of targets for README integration. It now uses
/// a centralized PackageInfoProvider to avoid duplicate process spawns.
public struct PackageInfoLoader {
  // MARK: - Nested Types

  /// Errors that can occur during package info loading.
  public enum LoadError: LocalizedError {
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

  /// Initializes a new PackageInfoLoader with a package info provider.
  ///
  /// - Parameter packageInfoProvider: Centralized provider for package information.
  public init(packageInfoProvider: PackageInfoProvider = PackageInfoProvider()) {
    self.packageInfoProvider = packageInfoProvider
  }

  // MARK: - Functions

  /// Loads package description and extracts target path information.
  ///
  /// This function uses the centralized PackageInfoProvider to get information
  /// about the package targets and their file system locations. The returned
  /// mapping is used to locate README.md files within each target directory.
  /// This eliminates duplicate process spawns and provides caching for improved performance.
  ///
  /// - Returns: Dictionary mapping target names to their relative file system paths.
  /// - Throws: `LoadError` if the package provider fails.
  public func loadPackageDescription() throws -> [String: String] {
    do {
      return try packageInfoProvider.loadTargetPaths()
    }
    catch let error as PackageInfoProvider.ProviderError {
      throw LoadError.providerError(error.localizedDescription)
    }
    catch {
      throw LoadError.providerError(error.localizedDescription)
    }
  }
}
