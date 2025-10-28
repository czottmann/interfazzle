import Foundation

/// A simple struct that represents configuration options
public struct ExampleConfig: Sendable {
  // MARK: - Static Properties

  /// Default configuration
  public static let `default` = ExampleConfig(
    debugEnabled: false,
    maxIterations: 10,
    timeout: nil
  )

  // MARK: - Properties

  /// Enable debug mode
  public var debugEnabled: Bool

  /// Maximum number of iterations
  public var maxIterations: Int

  /// Optional timeout interval
  public var timeout: TimeInterval?

  // MARK: - Private Properties

  /// Internal configuration version
  private var configVersion: String = "1.0.0"

  /// Internal checksum for validation
  private var checksum: String = ""

  /// Last modified timestamp
  private var lastModified: Date = .init()

  // MARK: - Lifecycle

  /// Initialize with custom configuration
  /// - Parameters:
  ///   - debugEnabled: Whether to enable debug mode
  ///   - maxIterations: Maximum number of allowed iterations
  ///   - timeout: Optional timeout in seconds
  public init(debugEnabled: Bool = false, maxIterations: Int = 10, timeout: TimeInterval? = nil) {
    self.debugEnabled = debugEnabled
    self.maxIterations = maxIterations
    self.timeout = timeout
    checksum = privateGenerateChecksum()
    lastModified = Date()
  }

  // MARK: - Functions

  /// Update configuration with new values
  /// - Parameters:
  ///   - debugEnabled: New debug mode setting
  ///   - maxIterations: New max iterations setting
  ///   - timeout: New timeout setting
  public mutating func update(debugEnabled: Bool? = nil, maxIterations: Int? = nil, timeout: TimeInterval? = nil) {
    if let debugEnabled {
      self.debugEnabled = debugEnabled
    }
    if let maxIterations {
      self.maxIterations = maxIterations
    }
    if let timeout {
      self.timeout = timeout
    }

    privateRefreshChecksum()
    lastModified = Date()
  }

  /// Validate the current configuration
  /// - Returns: True if configuration is valid
  public func validate() -> Bool {
    maxIterations > 0 && maxIterations <= 1000 &&
      (timeout == nil || timeout! > 0)
  }

  // MARK: - Private Functions

  /// Generate internal checksum for configuration integrity
  /// - Returns: A string checksum
  private func privateGenerateChecksum() -> String {
    let values = "\(debugEnabled)-\(maxIterations)-\(timeout ?? 0)-\(configVersion)"
    return String(values.hashValue)
  }

  /// Refresh the internal checksum after configuration changes
  private mutating func privateRefreshChecksum() {
    checksum = privateGenerateChecksum()
  }

  /// Internal validation for configuration values
  /// - Returns: True if internal validation passes
  private func privateValidateInternal() -> Bool {
    !checksum.isEmpty && lastModified <= Date()
  }

  /// Log configuration changes (private)
  /// - Parameter change: Description of the change
  private func privateLogChange(_ change: String) {
    if debugEnabled {
      print("[ExampleConfig] Changed: \(change)")
    }
  }
}
