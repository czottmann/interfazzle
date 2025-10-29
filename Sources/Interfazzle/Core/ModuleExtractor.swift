import Foundation

/// Extracts public module names from a Swift package.
///
/// This class provides functionality to query a Swift package and discover
/// which modules are exposed as public products that should be documented.
public struct ModuleExtractor {
  // MARK: - Nested Types

  /// Errors that can occur during module extraction.
  public enum ExtractionError: LocalizedError {
    case swiftCommandFailed
    case invalidJSON

    // MARK: - Computed Properties

    public var errorDescription: String? {
      switch self {
        case .swiftCommandFailed:
          "Failed to run 'swift package describe'"
        case .invalidJSON:
          "Failed to parse package description JSON"
      }
    }
  }

  /// Product information from package description.
  private struct PackageInfo: Codable {
    // MARK: - Nested Types

    struct Product: Codable {
      let targets: [String]
    }

    // MARK: - Properties

    let products: [Product]
  }

  // MARK: - Lifecycle

  /// Initializes a new ModuleExtractor.
  public init() {}

  // MARK: - Functions

  /// Extracts public module names from the Swift package description.
  ///
  /// This function runs `swift package describe --type json` to get the package
  /// information and extracts the target names from all products.
  ///
  /// - Returns: An array of module names that are exposed as products in the package.
  /// - Throws: `ExtractionError` if the command fails or JSON parsing fails.
  public func extractPublicModules() throws -> [String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["package", "describe", "--type", "json"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw ExtractionError.swiftCommandFailed
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()

    guard let packageInfo = try? JSONDecoder().decode(PackageInfo.self, from: data) else {
      throw ExtractionError.invalidJSON
    }

    /// Get all unique targets from products (these are the public modules)
    var modules = Set<String>()
    for product in packageInfo.products {
      modules.formUnion(product.targets)
    }

    return modules.sorted()
  }
}
