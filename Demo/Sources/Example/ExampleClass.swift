import Foundation

/// A concrete implementation of ExampleProtocol
public class ExampleClass: ExampleProtocol {
  // MARK: - Properties

  /// The name of the example instance
  public let name: String

  /// The current operation mode
  public private(set) var currentMode: OperationMode = .standard

  // MARK: - Private Properties

  /// Internal counter for tracking operations
  private var operationCount: Int = 0

  /// Cache for storing calculation results
  private var calculationCache: [Int: Int] = [:]

  /// Internal state flag
  private var isInitialized: Bool = false

  // MARK: - Lifecycle

  /// Initialize with a name
  /// - Parameter name: The name for this instance
  public init(name: String) {
    self.name = name
    isInitialized = true
    privateSetup()
  }

  // MARK: - Functions

  /// Returns a greeting message including the instance name
  public func greet() -> String {
    "Hello from \(name)!"
  }

  /// Doubles the input value
  /// - Parameter value: The value to double
  /// - Returns: The doubled value
  public func calculate(_ value: Int) -> Int {
    operationCount += 1

    if let cached = calculationCache[value] {
      return cached
    }

    let result = value * 2
    calculationCache[value] = result
    return result
  }

  /// A demonstration method that combines greeting and calculation
  /// - Parameter value: A value to use in the calculation
  /// - Returns: A tuple containing both greeting and calculation result
  public func demonstrate(with value: Int) -> (greeting: String, result: Int) {
    (greet(), calculate(value))
  }

  /// Change the operation mode
  /// - Parameter mode: The new operation mode
  public func setMode(_ mode: OperationMode) {
    currentMode = mode
    clearCache()
  }

  // MARK: - Private Functions

  /// Private setup method for initialization
  private func privateSetup() {
    operationCount = 0
    calculationCache.removeAll()
  }

  /// Clear the internal calculation cache
  private func clearCache() {
    calculationCache.removeAll()
  }

  /// Internal logging method
  /// - Parameter message: The message to log
  private func log(_ message: String) {
    if currentMode == .standard {
      print("[ExampleClass] \(message)")
    }
  }

  /// Validate input value
  /// - Parameter value: The value to validate
  /// - Returns: True if valid
  private func validateInput(_ value: Int) -> Bool {
    value >= 0 && value <= 1000
  }
}
