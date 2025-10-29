import Foundation

/// Builds symbol graphs for a Swift package.
///
/// This class provides functionality to compile a Swift package with symbol graph
/// generation enabled, producing the JSON files needed for documentation generation.
public struct SymbolGraphBuilder {
  // MARK: - Nested Types

  /// Errors that can occur during symbol graph building.
  public enum BuildError: LocalizedError {
    case buildFailed(exitCode: Int32, output: String)

    // MARK: - Computed Properties

    public var errorDescription: String? {
      switch self {
        case let .buildFailed(exitCode, output):
          "Build failed with exit code \(exitCode)\n\(output)"
      }
    }
  }

  // MARK: - Lifecycle

  /// Initializes a new SymbolGraphBuilder.
  public init() {}

  // MARK: - Functions

  /// Builds symbol graphs for the Swift package.
  ///
  /// This function runs `swift build` with symbol graph generation flags and creates
  /// the output directory if needed. Build output is captured and only shown on error
  /// unless verbose mode is enabled.
  ///
  /// - Parameters:
  ///   - symbolGraphsDir: The directory where symbol graph files should be generated.
  ///   - verbose: Whether to show full build output or suppress it (default behavior).
  /// - Throws: `BuildError.buildFailed` if the build fails with a non-zero exit status.
  public func build(symbolGraphsDir: String, verbose: Bool) throws {
    print("🔨 Building symbol graphs...")

    /// Create directory if needed
    let fm = FileManager.default
    try fm.createDirectory(atPath: symbolGraphsDir, withIntermediateDirectories: true)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = [
      "build",
      "-Xswiftc", "-emit-symbol-graph",
      "-Xswiftc", "-emit-symbol-graph-dir",
      "-Xswiftc", symbolGraphsDir,
    ]

    if verbose {
      /// Stream output in real-time
      try process.run()
      process.waitUntilExit()
    }
    else {
      /// Capture output, only show on error
      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      try process.run()
      process.waitUntilExit()

      if process.terminationStatus != 0 {
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        var output = ""
        if let stdout = String(data: outputData, encoding: .utf8), !stdout.isEmpty {
          output += stdout
        }
        if let stderr = String(data: errorData, encoding: .utf8), !stderr.isEmpty {
          output += stderr
        }

        throw BuildError.buildFailed(exitCode: process.terminationStatus, output: output)
      }
    }

    guard process.terminationStatus == 0 else {
      throw BuildError.buildFailed(exitCode: process.terminationStatus, output: "")
    }
  }
}
