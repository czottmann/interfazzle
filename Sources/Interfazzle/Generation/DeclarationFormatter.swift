import Foundation

/// Formats Swift declaration fragments into readable strings.
///
/// This struct provides utilities for converting symbol graph declaration fragments
/// into properly formatted Swift code strings for documentation output.
public struct DeclarationFormatter {
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

    /// For Swift symbols, use swift-demangle to get the proper name
    if preciseIdentifier.hasPrefix("s:") {
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
            if let lastDot = fullName.lastIndex(of: ".") {
              return String(fullName[fullName.index(after: lastDot)...])
            }
            return fullName
          }
        }
      }
      catch {
        /// Fall through to return nil
      }
    }

    return nil
  }
}
