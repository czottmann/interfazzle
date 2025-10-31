import Foundation

/// Centralized provider for Swift package information with caching.
///
/// This class provides a unified interface for querying Swift package information
/// while avoiding duplicate process spawns. It caches package description data
/// to eliminate the 50-100ms overhead per process spawn mentioned in ZCO-1553.
public class PackageInfoProvider {
  // MARK: - Nested Types

  /// Errors that can occur during package information loading.
  public enum ProviderError: LocalizedError {
    case swiftCommandFailed
    case invalidJSON
    case cacheError(String)

    // MARK: - Computed Properties

    public var errorDescription: String? {
      switch self {
        case .swiftCommandFailed:
          "Failed to run 'swift package describe'"
        case .invalidJSON:
          "Failed to parse package description JSON"
        case let .cacheError(message):
          "Cache error: \(message)"
      }
    }
  }

  /// Product information from package description for public module extraction.
  private struct PackageInfo: Codable {
    // MARK: - Nested Types

    struct Product: Codable {
      let targets: [String]
    }

    // MARK: - Properties

    let products: [Product]
  }

  // MARK: - Properties

  /// Cached package description data.
  private var cachedPackageDescription: PackageDescription?

  /// Cached package info data for product extraction.
  private var cachedPackageInfo: PackageInfo?

  /// Cached public module names.
  private var cachedPublicModules: [String]?

  /// Whether the cache has been populated.
  private var isCachePopulated = false

  /// Serial queue to ensure thread-safe cache access.
  private let cacheQueue = DispatchQueue(label: "com.interfazzle.packageinfoprovider")

  /// Shared JSON decoder for efficient package parsing.
  private let jsonDecoder = JSONDecoder()

  // MARK: - Lifecycle

  /// Initializes a new PackageInfoProvider.
  public init() {}

  // MARK: - Functions

  /// Loads and caches the complete package description.
  ///
  /// This method runs `swift package describe --type json` once and caches the result
  /// for subsequent calls. Subsequent calls return the cached data without spawning
  /// additional processes, eliminating the 50-100ms overhead per call.
  ///
  /// - Returns: PackageDescription with complete package information.
  /// - Throws: ProviderError if the command fails or JSON parsing fails.
  public func loadPackageDescription() throws -> PackageDescription {
    if let cached = cachedPackageDescription, isCachePopulated {
      return cached
    }

    let packageDesc = try fetchPackageDescriptionFromProcess()
    cacheQueue.sync {
      cachedPackageDescription = packageDesc
      isCachePopulated = true
    }
    return packageDesc
  }

  /// Extracts and caches public module names from the package description.
  ///
  /// This method reuses the cached package description to extract public module
  /// names without spawning additional processes. It gets all unique targets from
  /// products in the package (these are the public modules).
  ///
  /// - Returns: Array of module names that are exposed as products in the package.
  /// - Throws: ProviderError if the package description cannot be loaded.
  public func extractPublicModules() throws -> [String] {
    if let cached = cachedPublicModules, isCachePopulated {
      return cached
    }

    let packageInfo = try fetchPackageInfoFromProcess()
    var modules = Set<String>()
    for product in packageInfo.products {
      modules.formUnion(product.targets)
    }

    let sortedModules = modules.sorted()
    cacheQueue.sync {
      cachedPackageInfo = packageInfo
      cachedPublicModules = sortedModules
      isCachePopulated = true
    }
    return sortedModules
  }

  /// Loads target path information from the cached package description.
  ///
  /// This method reuses the cached package description to build a mapping of
  /// target names to their file system paths. This is used to locate README.md
  /// files within each target directory without spawning additional processes.
  ///
  /// - Returns: Dictionary mapping target names to their relative file system paths.
  /// - Throws: ProviderError if the package description cannot be loaded.
  public func loadTargetPaths() throws -> [String: String] {
    let packageDesc = try loadPackageDescription()

    /// Build a dictionary of target name -> path
    var targetPaths: [String: String] = [:]
    for target in packageDesc.targets {
      targetPaths[target.name] = target.path
    }

    return targetPaths
  }

  /// Clears the cached package information.
  ///
  /// This method invalidates all cached data, forcing the next call to
  /// reload fresh information from the Swift package. This is useful for
  /// testing or when the package configuration may have changed.
  public func clearCache() {
    cacheQueue.sync {
      cachedPackageDescription = nil
      cachedPackageInfo = nil
      cachedPublicModules = nil
      isCachePopulated = false
    }
  }

  // MARK: - Private Functions

  /// Fetches and decodes package information from the Swift process.
  ///
  /// This generic method performs the actual `swift package describe --type json` command
  /// and decodes the result into the specified type. This eliminates code duplication
  /// between methods that need different decodable types from the same command.
  ///
  /// - Parameter type: The Decodable type to decode the JSON response into.
  /// - Returns: Decoded instance of the specified type.
  /// - Throws: ProviderError if the command fails or JSON parsing fails.
  private func fetchPackageData<T: Decodable>(_ type: T.Type) throws -> T {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["package", "describe", "--type", "json"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw ProviderError.swiftCommandFailed
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()

    guard let result = try? jsonDecoder.decode(T.self, from: data) else {
      throw ProviderError.invalidJSON
    }

    return result
  }

  /// Fetches package info directly from the Swift process.
  ///
  /// This method performs the actual `swift package describe --type json` command
  /// and should only be called when the cache is empty. The result is cached
  /// for subsequent calls to avoid process spawn overhead.
  ///
  /// - Returns: PackageInfo parsed from the Swift command output.
  /// - Throws: ProviderError if the command fails or JSON parsing fails.
  private func fetchPackageInfoFromProcess() throws -> PackageInfo {
    try fetchPackageData(PackageInfo.self)
  }

  /// Fetches package description directly from the Swift process.
  ///
  /// This method performs the actual `swift package describe --type json` command
  /// and should only be called when the cache is empty. The result is cached
  /// for subsequent calls to avoid process spawn overhead.
  ///
  /// - Returns: PackageDescription parsed from the Swift command output.
  /// - Throws: ProviderError if the command fails or JSON parsing fails.
  private func fetchPackageDescriptionFromProcess() throws -> PackageDescription {
    try fetchPackageData(PackageDescription.self)
  }
}
