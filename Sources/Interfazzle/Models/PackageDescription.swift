import Foundation

/// Represents the structure of a Swift package description.
///
/// This struct is used to parse the JSON output from `swift package describe --type json`
/// and extract information about package targets and their file system locations.
public struct PackageDescription: Codable {
  // MARK: - Nested Types

  /// Represents a build target within a Swift package.
  ///
  /// A target corresponds to a module that can be built as part of the package.
  /// Each target has a name and a file system path where its source files are located.
  public struct Target: Codable {
    /// The name of the build target/module.
    ///
    /// This is the identifier used to reference the target within the package
    /// and corresponds to the module name that can be imported in Swift code.
    public let name: String

    /// The relative file system path to the target's source directory.
    ///
    /// This path is relative to the package root and points to the directory
    /// containing the target's Swift source files.
    public let path: String
  }

  // MARK: - Properties

  /// Array of all build targets defined in the package.
  ///
  /// This includes both library and executable targets that are part of the package.
  public let targets: [Target]
}
