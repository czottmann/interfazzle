import Foundation

/// Utilities for formatting Markdown content.
///
/// This struct provides helper functions for processing Markdown text,
/// particularly for adjusting heading levels and formatting documentation comments.
public struct MarkdownFormatter {
  // MARK: - Lifecycle

  /// Initializes a new MarkdownFormatter.
  public init() {}

  // MARK: - Functions

  /// Adjusts heading levels in markdown content to fit within documentation hierarchy.
  ///
  /// This function ensures that markdown headings are properly nested within the
  /// generated documentation by shifting all heading levels so the highest level
  /// becomes H3 (to fit under the main module H2 heading).
  ///
  /// - Parameter markdown: The markdown content to adjust.
  /// - Returns: Markdown with adjusted heading levels.
  public func adjustHeadingLevels(in markdown: String) -> String {
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

    /// Find the minimum heading level (highest priority heading)
    var minLevel: Int?
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("#") {
        /// Count the number of # characters
        let hashCount = trimmed.prefix(while: { $0 == "#" }).count
        if hashCount > 0, hashCount <= 6 {
          /// Make sure there's a space after the hashes (valid markdown heading)
          if trimmed.count > hashCount, trimmed[trimmed.index(trimmed.startIndex, offsetBy: hashCount)] == " " {
            if let current = minLevel {
              minLevel = min(current, hashCount)
            }
            else {
              minLevel = hashCount
            }
          }
        }
      }
    }

    /// If no headings found, return original
    guard let minLevel else {
      return markdown
    }

    /// Calculate shift needed to make minLevel become level 3 (H3)
    let targetLevel = 3
    let shift = targetLevel - minLevel

    /// If no shift needed, return original
    if shift == 0 {
      return markdown
    }

    /// Apply shift to all headings
    var result: [String] = []
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("#") {
        let hashCount = trimmed.prefix(while: { $0 == "#" }).count
        if hashCount > 0, hashCount <= 6 {
          /// Check for valid heading (space after hashes)
          if trimmed.count > hashCount, trimmed[trimmed.index(trimmed.startIndex, offsetBy: hashCount)] == " " {
            let newLevel = min(hashCount + shift, 6) // Cap at H6
            let newHashes = String(repeating: "#", count: newLevel)
            let content = trimmed.dropFirst(hashCount).trimmingCharacters(in: .whitespaces)
            result.append("\(newHashes) \(content)")
            continue
          }
        }
      }
      result.append(String(line))
    }

    return result.joined(separator: "\n")
  }

  /// Formats a documentation comment for output.
  ///
  /// This function converts a symbol's doc comment into formatted Markdown with
  /// appropriate indentation and filters out parameter sections.
  ///
  /// - Parameters:
  ///   - docComment: The documentation comment to format.
  ///   - indent: The indentation string to prepend to each line.
  /// - Returns: Formatted documentation comment string.
  public func formatDocComment(_ docComment: SymbolGraph.Symbol.DocComment?, indent: String = "") -> String {
    guard let docComment else {
      return ""
    }

    var result = ""
    var inParametersSection = false

    for line in docComment.lines {
      let text = line.text
      let trimmed = text.trimmingCharacters(in: .whitespaces)

      /// Skip parameters section as we'll show them inline in declarations
      if trimmed.hasPrefix("- Parameters:") || trimmed.hasPrefix("-Parameters:") {
        inParametersSection = true
        continue
      }

      if inParametersSection {
        if trimmed.hasPrefix("-"), !trimmed.contains(":") {
          /// New section, end parameters
          inParametersSection = false
        }
        else {
          /// Skip parameter details
          continue
        }
      }

      if !inParametersSection {
        result += "\(indent)/// \(text)\n"
      }
    }

    return result
  }
}
