import Foundation

// MARK: - SymbolLookup

/// Shared lookup structure for efficient symbol access.
///
/// This struct provides optimized lookups that can be reused across multiple
/// methods to avoid redundant dictionary creation from the same symbol data.
private struct SymbolLookup {
  // MARK: - Properties

  /// Map of symbol IDs to symbols for O(1) lookup.
  let symbolsByID: [String: SymbolGraph.Symbol]

  /// Set of symbol IDs for fast existence checking.
  let symbolIDs: Set<String>

  // MARK: - Lifecycle

  /// Initialize lookup structure from symbols array.
  /// - Parameter symbols: Array of symbols to create lookup for.
  init(symbols: [SymbolGraph.Symbol]) {
    symbolsByID = Dictionary(uniqueKeysWithValues: symbols.map { ($0.identifier.precise, $0) })
    symbolIDs = Set(symbols.map(\.identifier.precise))
  }
}

// MARK: - SymbolSorter

/// Sorts symbols based on dependencies and type hierarchy.
///
/// This struct provides sophisticated sorting algorithms for organizing symbols
/// in documentation, ensuring that dependencies appear before dependents and
/// maintaining a logical type hierarchy.
public struct SymbolSorter {
  // MARK: - Lifecycle

  /// Initializes a new SymbolSorter.
  public init() {}

  // MARK: - Functions

  /// Finds the main symbol that should appear first in documentation.
  ///
  /// This method identifies the most important symbol in a module that should
  /// be highlighted first. It prioritizes symbols that are base classes in
  /// inheritance hierarchies, or symbols whose names match the module name.
  ///
  /// - Parameters:
  ///   - symbols: Array of symbols to search through.
  ///   - relationships: Array of relationships to analyze inheritance.
  ///   - moduleName: The name of the module being documented.
  /// - Returns: The main symbol if one is identified, nil otherwise.
  public func findMainSymbol(symbols: [SymbolGraph.Symbol],
                             relationships: [SymbolGraph.Relationship],
                             moduleName: String) -> SymbolGraph.Symbol?
  {
    /// Build a shared lookup structure for O(1) access
    let lookup = SymbolLookup(symbols: symbols)

    /// First priority: Find inheritance hierarchy - look for base classes/structs that others inherit from
    var inheritanceCounts: [String: Int] = [:]
    for relationship in relationships {
      if relationship.kind == "inheritsFrom" {
        let targetID = relationship.target
        /// Check if the target is one of our symbols
        if lookup.symbolsByID[targetID] != nil {
          inheritanceCounts[targetID, default: 0] += 1
        }
      }
    }

    /// Find the symbol with the most inheritors
    if let mostInheritedID = inheritanceCounts.max(by: { $0.value < $1.value })?.key,
       let mostInheritedSymbol = lookup.symbolsByID[mostInheritedID]
    {
      return mostInheritedSymbol
    }

    /// Second priority: Look for symbol with name matching the module name
    if let moduleMatchingSymbol = symbols.first(where: { $0.names.title == moduleName }) {
      return moduleMatchingSymbol
    }

    return nil
  }

  /// Builds a dependency graph showing relationships between symbols.
  ///
  /// This method analyzes symbol relationships to create a dependency graph where
  /// each symbol points to the symbols it depends on. This is used for topological
  /// sorting to ensure dependencies are documented before dependent symbols.
  ///
  /// - Parameters:
  ///   - symbols: Array of symbols to include in the graph.
  ///   - relationships: Array of relationships to analyze.
  /// - Returns: Dictionary mapping symbol IDs to sets of dependency symbol IDs.
  public func buildDependencyGraph(symbols: [SymbolGraph.Symbol],
                                   relationships: [SymbolGraph.Relationship]) -> [String: Set<String>]
  {
    /// Build a shared lookup structure for O(1) access
    let lookup = SymbolLookup(symbols: symbols)

    /// Build a map of symbol IDs to their dependencies
    var dependencies: [String: Set<String>] = [:]

    /// Initialize empty dependencies for all symbols
    for symbol in symbols {
      dependencies[symbol.identifier.precise] = Set<String>()
    }

    /// Analyze relationships to build dependencies
    for relationship in relationships {
      let sourceID = relationship.source
      let targetID = relationship.target

      /// If both source and target are in our symbols, source depends on target
      if lookup.symbolIDs.contains(sourceID),
         lookup.symbolIDs.contains(targetID)
      {
        dependencies[sourceID, default: Set<String>()].insert(targetID)
      }
    }

    return dependencies
  }

  /// Performs topological sort on symbols based on their dependencies using Kahn's algorithm.
  ///
  /// This method sorts symbols so that dependencies appear before the symbols
  /// that depend on them. This ensures proper documentation order where base
  /// classes and protocols are documented before their subclasses/conformers.
  /// Uses O(n+m) complexity for efficient processing of large dependency graphs.
  ///
  /// - Parameters:
  ///   - symbols: Array of symbols to sort.
  ///   - dependencies: Dependency graph mapping symbol IDs to their dependencies.
  /// - Returns: Array of symbols sorted in dependency order.
  public func topologicalSort(symbols: [SymbolGraph.Symbol],
                              dependencies: [String: Set<String>]) -> [SymbolGraph.Symbol]
  {
    /// Build a shared lookup structure for O(1) access
    let lookup = SymbolLookup(symbols: symbols)

    /// Calculate in-degree for each symbol (number of incoming edges)
    var inDegree: [String: Int] = [:]
    for symbol in symbols {
      inDegree[symbol.identifier.precise] = 0
    }

    /// Count dependencies for each symbol
    for (symbolID, deps) in dependencies {
      for dep in deps {
        /// Only count dependencies that are within our symbol set
        if lookup.symbolIDs.contains(dep) {
          inDegree[symbolID, default: 0] += 1
        }
      }
    }

    /// Initialize queue with symbols that have no dependencies (in-degree = 0)
    var queue: [SymbolGraph.Symbol] = []
    for symbol in symbols {
      if inDegree[symbol.identifier.precise] == 0 {
        queue.append(symbol)
      }
    }

    var result: [SymbolGraph.Symbol] = []

    /// Process symbols in queue, adding dependents as their in-degree becomes zero
    while !queue.isEmpty {
      let current = queue.removeFirst()
      result.append(current)

      let currentID = current.identifier.precise

      /// Find symbols that depend on the current symbol and reduce their in-degree
      for (symbolID, deps) in dependencies {
        if deps.contains(currentID), lookup.symbolIDs.contains(symbolID) {
          inDegree[symbolID]! -= 1
          if inDegree[symbolID] == 0 {
            queue.append(lookup.symbolsByID[symbolID]!)
          }
        }
      }
    }

    /// If we have remaining symbols, there's a cycle - add them in original order
    let processedIDs = Set(result.map(\.identifier.precise))
    let remainingSymbols = symbols.filter { !processedIDs.contains($0.identifier.precise) }
    result.append(contentsOf: remainingSymbols)

    return result
  }

  /// Determines the hierarchy rank for a symbol kind identifier.
  ///
  /// This method assigns a numeric rank to different symbol types to establish
  /// a documentation hierarchy. Lower ranks appear first in the documentation.
  /// The hierarchy is: Classes → Structs → Enums → Protocols → Extensions → Macros → Functions.
  ///
  /// - Parameter kindIdentifier: The kind identifier from a symbol graph.
  /// - Returns: Integer rank where lower numbers indicate higher priority in documentation.
  public func getTypeHierarchyRank(_ kindIdentifier: String) -> Int {
    /// Define hierarchy: Classes (1) → Structs (2) → Enums (3) → Protocols (4) → Extensions (5) → Macros (6) →
    /// Functions (7)
    switch kindIdentifier {
      case "swift.class":
        1
      case "swift.struct":
        2
      case "swift.enum":
        3
      case "swift.protocol":
        4
      case let kind where kind.contains("extension"):
        5
      case "swift.macro":
        6
      case "swift.func":
        7
      default:
        8
    }
  }

  /// Sorts symbols by dependency order and type hierarchy.
  ///
  /// This method combines topological sorting (for dependencies) with hierarchical
  /// sorting (by symbol type) to produce an optimal documentation order. Dependencies
  /// are documented first, then symbols are grouped by type hierarchy.
  ///
  /// - Parameters:
  ///   - symbols: Array of symbols to sort.
  ///   - dependencies: Dependency graph for the symbols.
  /// - Returns: Array of symbols sorted by dependencies and then by type hierarchy.
  public func sortSymbolsByHierarchy(symbols: [SymbolGraph.Symbol],
                                     dependencies: [String: Set<String>]) -> [SymbolGraph.Symbol]
  {
    /// First, sort by dependencies using topological sort
    let dependencySorted = topologicalSort(symbols: symbols, dependencies: dependencies)

    /// Then, group by type hierarchy while preserving dependency order where possible
    let grouped = Dictionary(grouping: dependencySorted) { symbol in
      getTypeHierarchyRank(symbol.kind.identifier)
    }

    /// Sort groups by hierarchy rank and flatten
    let sortedRanks = grouped.keys.sorted()
    return sortedRanks.flatMap { grouped[$0]?.sorted(by: { $0.names.title < $1.names.title }) ?? [] }
  }
}
