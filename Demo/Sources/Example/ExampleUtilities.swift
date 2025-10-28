import Foundation

/// A namespace for utility functions
public enum ExampleUtilities {
  /// Validates if a string meets basic criteria
  /// - Parameter input: The string to validate
  /// - Returns: True if valid, false otherwise
  public static func validate(_ input: String) -> Bool {
    !input.isEmpty && input.count >= 3
  }

  /// Formats a number with thousands separator
  /// - Parameter number: The number to format
  /// - Returns: Formatted string representation
  public static func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
  }

  /// Calculate the factorial of a number
  /// - Parameter n: The number to calculate factorial for
  /// - Returns: Factorial result
  public static func factorial(_ n: Int) -> Int {
    guard n >= 0 else {
      return 0
    }

    return n <= 1 ? 1 : n * factorial(n - 1)
  }

  // MARK: - Private Functions

  /// Internal helper to check if string contains only alphanumeric characters
  /// - Parameter input: The string to check
  /// - Returns: True if alphanumeric only
  private static func privateIsAlphanumeric(_ input: String) -> Bool {
    input.allSatisfy { $0.isLetter || $0.isNumber }
  }

  /// Internal helper to count words in a string
  /// - Parameter input: The string to analyze
  /// - Returns: Number of words
  private static func privateWordCount(_ input: String) -> Int {
    input.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .count
  }

  /// Internal helper to validate email format (basic)
  /// - Parameter email: The email to validate
  /// - Returns: True if appears to be valid email format
  private static func privateValidateEmail(_ email: String) -> Bool {
    email.contains("@") && email.contains(".") && email.count > 5
  }

  /// Internal helper to extract numeric characters from string
  /// - Parameter input: The string to extract from
  /// - Returns: String containing only numbers
  private static func privateExtractNumbers(_ input: String) -> String {
    input.filter(\.isNumber)
  }

  /// Internal helper to calculate string similarity
  /// - Parameter string1: First string
  /// - Parameter string2: Second string
  /// - Returns: Similarity score between 0 and 1
  private static func privateStringSimilarity(_ string1: String, _ string2: String) -> Double {
    let longer = string1.count > string2.count ? string1 : string2
    let shorter = string1.count > string2.count ? string2 : string1

    if longer.isEmpty {
      return 1.0
    }

    let editDistance = privateLevenshteinDistance(longer, shorter)
    return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
  }

  /// Calculate Levenshtein distance between two strings
  /// - Parameter s1: First string
  /// - Parameter s2: Second string
  /// - Returns: Edit distance
  private static func privateLevenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let s1Array = Array(s1)
    let s2Array = Array(s2)
    let s1Count = s1Array.count
    let s2Count = s2Array.count

    var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)

    for i in 0...s1Count {
      matrix[i][0] = i
    }

    for j in 0...s2Count {
      matrix[0][j] = j
    }

    for i in 1...s1Count {
      for j in 1...s2Count {
        let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
        matrix[i][j] = min(
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost // substitution
        )
      }
    }

    return matrix[s1Count][s2Count]
  }
}
