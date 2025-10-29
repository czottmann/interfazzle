import Foundation

/// Loads package description and extracts target path information.
///
/// This class provides functionality to query a Swift package and discover
/// the file system locations of targets for README integration.
public struct PackageInfoLoader {
  // MARK: - Nested Types

  /// Errors that can occur during package info loading.
  public enum LoadError: LocalizedError {
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

  // MARK: - Lifecycle

  /// Initializes a new PackageInfoLoader.
  public init() {}

  // MARK: - Functions

  /// Loads package description and extracts target path information.
  ///
  /// This function runs `swift package describe --type json` to get information
  /// about the package targets and their file system locations. The returned
  /// mapping is used to locate README.md files within each target directory.
  ///
  /// - Returns: Dictionary mapping target names to their relative file system paths.
  /// - Throws: `LoadError` if the command fails or JSON parsing fails.
  public func loadPackageDescription() throws -> [String: String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["package", "describe", "--type", "json"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw LoadError.swiftCommandFailed
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()

    guard let packageDesc = try? JSONDecoder().decode(PackageDescription.self, from: data) else {
      throw LoadError.invalidJSON
    }

    /// Build a dictionary of target name -> path
    var targetPaths: [String: String] = [:]
    for target in packageDesc.targets {
      targetPaths[target.name] = target.path
    }

    return targetPaths
  }
}
