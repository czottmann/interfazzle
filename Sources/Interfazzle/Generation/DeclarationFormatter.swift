import Foundation

/// Formats Swift declaration fragments into readable strings.
///
/// This class provides utilities for converting symbol graph declaration fragments
/// into properly formatted Swift code strings for documentation output.
/// Implements caching for Swift demangle operations to avoid repeated process calls.
public class DeclarationFormatter {
  // MARK: - Properties

  /// Cache for demangled type names to avoid repeated process calls.
  private var demangleCache: [String: String] = [:]

  // MARK: - Lifecycle

  /// Initializes a new DeclarationFormatter.
  public init() {}

  // MARK: - Functions

  /// Formats declaration fragments into a readable string.
  ///
  /// This function filters out unwanted keywords/attributes and optionally adds
  /// a public modifier if not already present.
  ///
  /// - Parameters:
  ///   - fragments: The declaration fragments to format.
  ///   - addPublic: Whether to add "public" modifier if not present.
  /// - Returns: Formatted declaration string.
  public func formatDeclaration(fragments: [SymbolGraph.Symbol.DeclarationFragment], addPublic: Bool) -> String {
    /// Filter out unwanted keywords/attributes
    let filtered = fragments.filter {
      !["nonisolated", "@MainActor"].contains($0.spelling.trimmingCharacters(in: .whitespaces))
    }

    var declaration = filtered.map(\.spelling).joined()

    /// Add public modifier if needed and not already present
    if addPublic, !declaration.hasPrefix("public") {
      declaration = "public " + declaration
    }

    return declaration
  }

  /// Extracts a readable type name from a precise symbol identifier.
  ///
  /// This method attempts to demangle Swift symbol identifiers and map them to
  /// human-readable type names. It handles Objective-C symbols, standard library types,
  /// and uses swift-demangle for complex Swift symbols.
  ///
  /// - Parameter preciseIdentifier: The precise identifier from a symbol graph.
  /// - Returns: A readable type name if extraction succeeds, nil otherwise.
  public func extractTypeName(from preciseIdentifier: String) -> String? {
    /// Handle Objective-C symbols: c:objc(cs)ClassName or c:objc(pl)ProtocolName
    if preciseIdentifier.hasPrefix("c:objc(cs)") || preciseIdentifier.hasPrefix("c:objc(pl)") {
      let parts = preciseIdentifier.components(separatedBy: ")")
      return parts.last
    }

    /// Handle common Swift standard library types
    let swiftStdLibMap: [String: String] = [
      "s:SH": "Hashable",
      "s:SQ": "Equatable",
      "s:s7CVarArgP": "CVarArg",
      "s:SE": "Encodable",
      "s:Se": "Decodable",
      "s:Sb": "Bool",
      "s:Si": "Int",
      "s:Ss": "String",
      "s:Sa": "Array",
    ]

    if let mapped = swiftStdLibMap[preciseIdentifier] {
      return mapped
    }

    /// For Swift symbols, use swift-demangle to get the proper name with caching
    if preciseIdentifier.hasPrefix("s:") {
      /// Check cache first
      if let cached = demangleCache[preciseIdentifier] {
        return cached
      }

      /// Convert to mangled format that swift-demangle expects (replace "s:" with "$s")
      let mangled = "$s" + preciseIdentifier.dropFirst(2)

      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
      process.arguments = ["demangle", mangled]

      let pipe = Pipe()
      process.standardOutput = pipe

      do {
        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if let demangled = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
          /// Output format: "$sMANGLED ---> Module.TypeName"
          if let arrowRange = demangled.range(of: " ---> ") {
            let fullName = String(demangled[arrowRange.upperBound...])
            /// Extract just the type name (last component after last dot)
            let typeName: String =
              if let lastDot = fullName.lastIndex(of: ".") {
                String(fullName[fullName.index(after: lastDot)...])
              }
              else {
                fullName
              }
            /// Cache the result
            demangleCache[preciseIdentifier] = typeName
            return typeName
          }
        }
      }
      catch {
        /// Fall through to return nil, but cache the failure to avoid repeated attempts
        demangleCache[preciseIdentifier] = nil
      }
    }

    return nil
  }

  /// Batch demangles multiple Swift identifiers in a single process call.
  ///
  /// This method takes multiple identifiers and processes them in a single
  /// swift-demangle call to reduce process spawn overhead. Results are cached.
  ///
  /// - Parameter identifiers: Array of Swift precise identifiers to demangle.
  /// - Returns: Dictionary mapping identifiers to their demangled type names.
  func batchDemangle(identifiers: [String]) -> [String: String] {
    var results: [String: String] = [:]
    var uncachedIdentifiers: [String] = []

    /// Check cache first for all identifiers
    for identifier in identifiers {
      if let cached = demangleCache[identifier] {
        results[identifier] = cached
      }
      else if identifier.hasPrefix("s:") {
        uncachedIdentifiers.append(identifier)
      }
      else {
        results[identifier] = nil
      }
    }

    /// Process uncached identifiers in batch
    if !uncachedIdentifiers.isEmpty {
      let batchResults = processBatchDemangle(identifiers: uncachedIdentifiers)

      /// Cache and merge results
      for (identifier, result) in batchResults {
        demangleCache[identifier] = result
        results[identifier] = result
      }
    }

    return results
  }

  /// Processes multiple identifiers in a single swift-demangle call.
  ///
  /// - Parameter identifiers: Array of Swift identifiers to demangle.
  /// - Returns: Dictionary mapping identifiers to demangled type names.
  private func processBatchDemangle(identifiers: [String]) -> [String: String] {
    var results: [String: String] = [:]

    /// Convert identifiers to mangled format
    let mangledIdentifiers = identifiers.map { "$s" + $0.dropFirst(2) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["demangle"] + mangledIdentifiers

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
      try process.run()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()

      if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
        /// Parse batch output format
        let lines = output.split(separator: "\n")

        for (index, line) in lines.enumerated() {
          guard index < identifiers.count else {
            break
          }

          /// Output format: "$sMANGLED ---> Module.TypeName"
          if let arrowRange = line.range(of: " ---> ") {
            let fullName = String(line[arrowRange.upperBound...])
            let identifier = identifiers[index]

            /// Extract just the type name (last component after last dot)
            if let lastDot = fullName.lastIndex(of: ".") {
              results[identifier] = String(fullName[fullName.index(after: lastDot)...])
            }
            else {
              results[identifier] = fullName
            }
          }
          else {
            /// Failed to demangle, cache the failure
            results[identifiers[index]] = nil
          }
        }
      }
    }
    catch {
      /// Batch processing failed, cache failures for all identifiers
      for identifier in identifiers {
        results[identifier] = nil
      }
    }

    return results
  }
}
