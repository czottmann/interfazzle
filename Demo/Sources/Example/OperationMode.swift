import Foundation

/// An enum representing different operation modes
public enum OperationMode {
  // MARK: - Public Cases

  /// Standard operation mode
  case standard
  /// Fast operation mode with reduced accuracy
  case fast
  /// Accurate operation mode with increased processing
  case accurate

  // MARK: - Internal Cases

  /// Internal testing mode (not exposed publicly)
  case testing
  /// Legacy compatibility mode (not exposed publicly)
  case legacy

  // MARK: - Computed Properties

  /// Returns a description of the mode
  public var description: String {
    switch self {
      case .standard:
        "Standard mode"
      case .fast:
        "Fast mode (reduced accuracy)"
      case .accurate:
        "Accurate mode (increased processing)"
      case .testing:
        privateInternalDescription()
      case .legacy:
        privateLegacyDescription()
    }
  }

  /// The performance multiplier for this mode
  public var performanceMultiplier: Double {
    switch self {
      case .standard:
        1.0
      case .fast:
        0.5
      case .accurate:
        1.5
      case .testing:
        2.0
      case .legacy:
        0.8
    }
  }

  // MARK: - Functions

  /// Check if the mode supports high precision operations
  /// - Returns: True if high precision is supported
  public func supportsHighPrecision() -> Bool {
    switch self {
      case .accurate,
           .standard,
           .testing:
        true
      case .fast,
           .legacy:
        false
    }
  }

  /// Get the recommended timeout for this mode
  /// - Parameter baseTimeout: The base timeout in seconds
  /// - Returns: Adjusted timeout for this mode
  public func recommendedTimeout(baseTimeout: TimeInterval) -> TimeInterval {
    baseTimeout * performanceMultiplier
  }

  // MARK: - Private Functions

  /// Internal description for internal mode
  /// - Returns: Description string
  private func privateInternalDescription() -> String {
    "Internal testing mode"
  }

  /// Legacy description for legacy mode
  /// - Returns: Description string
  private func privateLegacyDescription() -> String {
    "Legacy compatibility mode"
  }

  /// Internal validation for mode transitions
  /// - Parameter newMode: The mode to transition to
  /// - Returns: True if transition is allowed
  private func privateCanTransitionTo(_ newMode: OperationMode) -> Bool {
    switch (self, newMode) {
      case (_, .testing),
           (.testing, _):
        false
      case (.legacy, .fast):
        false
      default:
        true
    }
  }

  /// Get internal performance metrics
  /// - Returns: Array of metric names
  private func privateGetPerformanceMetrics() -> [String] {
    switch self {
      case .standard:
        ["speed", "accuracy", "memory"]
      case .fast:
        ["speed"]
      case .accurate:
        ["accuracy", "memory"]
      case .testing:
        ["all_metrics"]
      case .legacy:
        ["basic_metrics"]
    }
  }
}
