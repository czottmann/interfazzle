import Foundation
import Testing
@testable import Interfazzle

@Suite("Interfazzle Tests")
struct InterfazzleTests {
  @Suite("PackageValidator")
  struct PackageValidatorTests {
    @Test("Validation succeeds when Package.swift exists")
    func validationSucceedsWhenPackageExists() throws {
      /// Since we're running from the package root, Package.swift should exist
      let validator = PackageValidator()
      #expect(throws: Never.self) {
        try validator.validate()
      }
    }

    @Test("Validation fails when Package.swift missing")
    func validationFailsWhenPackageMissing() throws {
      /// Change to a directory without Package.swift
      let fm = FileManager.default
      let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let originalDir = fm.currentDirectoryPath
      fm.changeCurrentDirectoryPath(tempDir.path)

      defer {
        fm.changeCurrentDirectoryPath(originalDir)
        try? fm.removeItem(at: tempDir)
      }

      let validator = PackageValidator()
      #expect(throws: PackageValidator.ValidationError.self) {
        try validator.validate()
      }
    }
  }

  @Suite("Config")
  struct ConfigTests {
    @Test("Default configuration has expected values")
    func defaultConfigurationValues() {
      let config = Config.default

      #expect(config.symbolGraphsDir == ".build/symbol-graphs")
      #expect(config.outputDir == "docs")
      #expect(config.modules == nil)
      #expect(config.generateOnly == false)
      #expect(config.verbose == false)
      #expect(config.beLenient == false)
      #expect(config.includeReexported == false)
    }

    @Test("Custom configuration preserves values")
    func customConfigurationValues() {
      let config = Config(
        symbolGraphsDir: "custom-graphs",
        outputDir: "custom-docs",
        modules: ["Module1", "Module2"],
        generateOnly: true,
        verbose: true,
        beLenient: true,
        includeReexported: true
      )

      #expect(config.symbolGraphsDir == "custom-graphs")
      #expect(config.outputDir == "custom-docs")
      #expect(config.modules == ["Module1", "Module2"])
      #expect(config.generateOnly == true)
      #expect(config.verbose == true)
      #expect(config.beLenient == true)
      #expect(config.includeReexported == true)
    }
  }

  @Suite("DeclarationFormatter")
  struct DeclarationFormatterTests {
    @Test("Formats simple declaration")
    func formatsSimpleDeclaration() {
      let fragments = [
        SymbolGraph.Symbol.DeclarationFragment(kind: "keyword", spelling: "struct"),
        SymbolGraph.Symbol.DeclarationFragment(kind: "text", spelling: " "),
        SymbolGraph.Symbol.DeclarationFragment(kind: "identifier", spelling: "MyStruct"),
      ]

      let formatter = DeclarationFormatter()
      let result = formatter.formatDeclaration(fragments: fragments, addPublic: false)

      #expect(result == "struct MyStruct")
    }

    @Test("Adds public modifier when requested")
    func addsPublicModifier() {
      let fragments = [
        SymbolGraph.Symbol.DeclarationFragment(kind: "keyword", spelling: "struct"),
        SymbolGraph.Symbol.DeclarationFragment(kind: "text", spelling: " "),
        SymbolGraph.Symbol.DeclarationFragment(kind: "identifier", spelling: "MyStruct"),
      ]

      let formatter = DeclarationFormatter()
      let result = formatter.formatDeclaration(fragments: fragments, addPublic: true)

      #expect(result == "public struct MyStruct")
    }

    @Test("Does not duplicate public modifier")
    func doesNotDuplicatePublicModifier() {
      let fragments = [
        SymbolGraph.Symbol.DeclarationFragment(kind: "keyword", spelling: "public"),
        SymbolGraph.Symbol.DeclarationFragment(kind: "text", spelling: " "),
        SymbolGraph.Symbol.DeclarationFragment(kind: "keyword", spelling: "struct"),
        SymbolGraph.Symbol.DeclarationFragment(kind: "text", spelling: " "),
        SymbolGraph.Symbol.DeclarationFragment(kind: "identifier", spelling: "MyStruct"),
      ]

      let formatter = DeclarationFormatter()
      let result = formatter.formatDeclaration(fragments: fragments, addPublic: true)

      #expect(result == "public struct MyStruct")
    }

    @Test("extractTypeName handles standard library types")
    func handlesStandardLibraryTypes() {
      let formatter = DeclarationFormatter()

      #expect(formatter.extractTypeName(from: "s:SH") == "Hashable")
      #expect(formatter.extractTypeName(from: "s:SQ") == "Equatable")
      #expect(formatter.extractTypeName(from: "s:Ss") == "String")
      #expect(formatter.extractTypeName(from: "s:Si") == "Int")
    }

    @Test("extractTypeName caches failed demangle attempts")
    func cachesFailedDemangleAttempts() {
      let formatter = DeclarationFormatter()

      /// Try to demangle an invalid Swift identifier
      /// This should fail and cache the failure as nil
      let invalidIdentifier = "s:INVALID_IDENTIFIER"

      /// First call - will attempt to demangle and cache failure
      let result1 = formatter.extractTypeName(from: invalidIdentifier)
      #expect(result1 == nil)

      /// Second call - should return cached nil without attempting to demangle again
      /// We can't directly verify it's cached, but if it returns nil quickly, it worked
      let result2 = formatter.extractTypeName(from: invalidIdentifier)
      #expect(result2 == nil)
    }

    @Test("extractTypeName handles Objective-C symbols")
    func handlesObjectiveCSymbols() {
      let formatter = DeclarationFormatter()

      /// Test Objective-C class symbol
      let classResult = formatter.extractTypeName(from: "c:objc(cs)NSString")
      #expect(classResult == "NSString")

      /// Test Objective-C protocol symbol
      let protocolResult = formatter.extractTypeName(from: "c:objc(pl)NSCopying")
      #expect(protocolResult == "NSCopying")
    }

    @Test("extractTypeName returns nil for non-Swift symbols")
    func returnsNilForNonSwiftSymbols() {
      let formatter = DeclarationFormatter()

      /// Test C symbol
      let result = formatter.extractTypeName(from: "c:@F@some_c_function")
      #expect(result == nil)
    }
  }

  @Suite("SymbolSorter")
  struct SymbolSorterTests {
    @Test("findMainSymbol returns nil for empty symbols")
    func findsNoMainSymbolInEmptyArray() {
      let sorter = SymbolSorter()
      let result = sorter.findMainSymbol(
        symbols: [],
        relationships: [],
        moduleName: "TestModule"
      )

      #expect(result == nil)
    }

    @Test("topologicalSort handles empty symbols")
    func topologicalSortHandlesEmptySymbols() {
      let sorter = SymbolSorter()
      let result = sorter.topologicalSort(symbols: [], dependencies: [:])

      #expect(result.isEmpty)
    }

    @Test("topologicalSort handles symbols with no dependencies")
    func topologicalSortHandlesNoDependencies() {
      let sorter = SymbolSorter()

      /// Create test symbols
      let symbol1 = createTestSymbol(name: "Symbol1", id: "s:1")
      let symbol2 = createTestSymbol(name: "Symbol2", id: "s:2")

      let symbols = [symbol1, symbol2]
      let dependencies: [String: Set<String>] = [
        "s:1": Set<String>(),
        "s:2": Set<String>(),
      ]

      let result = sorter.topologicalSort(symbols: symbols, dependencies: dependencies)

      /// Both symbols should be in result
      #expect(result.count == 2)
    }

    @Test("topologicalSort handles circular dependencies")
    func topologicalSortHandlesCircularDependencies() {
      let sorter = SymbolSorter()

      /// Create test symbols with circular dependency
      let symbol1 = createTestSymbol(name: "Symbol1", id: "s:1")
      let symbol2 = createTestSymbol(name: "Symbol2", id: "s:2")

      let symbols = [symbol1, symbol2]
      let dependencies: [String: Set<String>] = [
        "s:1": Set(["s:2"]),
        "s:2": Set(["s:1"]),
      ]

      let result = sorter.topologicalSort(symbols: symbols, dependencies: dependencies)

      /// Should still return all symbols despite cycle
      #expect(result.count == 2)
    }

    @Test("topologicalSort handles inconsistent data gracefully")
    func topologicalSortHandlesInconsistentData() {
      let sorter = SymbolSorter()

      /// Create test symbols
      let symbol1 = createTestSymbol(name: "Symbol1", id: "s:1")

      let symbols = [symbol1]

      /// Dependencies reference a non-existent symbol
      let dependencies: [String: Set<String>] = [
        "s:1": Set(["s:999"]), // Non-existent symbol
        "s:999": Set<String>(), // Symbol not in symbols array
      ]

      /// Should not crash with force unwrap
      let result = sorter.topologicalSort(symbols: symbols, dependencies: dependencies)

      /// Should still return the valid symbol
      #expect(result.count == 1)
      #expect(result[0].identifier.precise == "s:1")
    }

    @Test("findMainSymbol selection is deterministic with equal inheritance counts")
    func findMainSymbolIsDeterministic() {
      let sorter = SymbolSorter()

      /// Create three symbols that will each be inherited from once
      let baseA = createTestSymbol(name: "BaseA", id: "s:baseA")
      let baseB = createTestSymbol(name: "BaseB", id: "s:baseB")
      let baseC = createTestSymbol(name: "BaseC", id: "s:baseC")
      let derived1 = createTestSymbol(name: "Derived1", id: "s:d1")
      let derived2 = createTestSymbol(name: "Derived2", id: "s:d2")
      let derived3 = createTestSymbol(name: "Derived3", id: "s:d3")

      let symbols = [baseA, baseB, baseC, derived1, derived2, derived3]

      /// All three base symbols have equal inheritance count (1)
      let relationships = [
        SymbolGraph.Relationship(kind: "inheritsFrom", source: "s:d1", target: "s:baseA"),
        SymbolGraph.Relationship(kind: "inheritsFrom", source: "s:d2", target: "s:baseB"),
        SymbolGraph.Relationship(kind: "inheritsFrom", source: "s:d3", target: "s:baseC"),
      ]

      /// Run multiple times to ensure deterministic selection
      var results: Set<String> = []
      for _ in 1...10 {
        if let mainSymbol = sorter.findMainSymbol(
          symbols: symbols,
          relationships: relationships,
          moduleName: "TestModule"
        ) {
          results.insert(mainSymbol.names.title)
        }
      }

      /// Should always select the same symbol (alphabetically first: "BaseA")
      #expect(results.count == 1)
      #expect(results.first == "BaseA")
    }

    /// Helper to create test symbols
    private func createTestSymbol(name: String, id: String) -> SymbolGraph.Symbol {
      SymbolGraph.Symbol(
        kind: SymbolGraph.Symbol.Kind(
          identifier: "swift.struct",
          displayName: "Structure"
        ),
        identifier: SymbolGraph.Symbol.Identifier(
          precise: id,
          interfaceLanguage: "swift"
        ),
        pathComponents: [name],
        names: SymbolGraph.Symbol.Names(
          title: name,
          subHeading: nil
        ),
        docComment: nil,
        declarationFragments: nil,
        functionSignature: nil,
        accessLevel: "public"
      )
    }
  }

  @Suite("PackageInfoProvider")
  struct PackageInfoProviderTests {
    /// NOTE: These tests are disabled because they spawn `swift package describe`
    /// processes which cause hangs/deadlocks when running inside `swift test`.
    /// The PackageInfoProvider functionality is integration-tested through the
    /// CLI commands which run outside the test environment.

    @Test("Cache is populated after loadPackageDescription", .disabled("Spawns swift process - causes test hang"))
    func cachePopulatedAfterLoadPackageDescription() throws {
      /// This test verifies that calling loadPackageDescription sets the cache flag
      /// Running in the actual package directory so swift package describe works
      let provider = PackageInfoProvider()

      /// First call should populate cache
      _ = try provider.loadPackageDescription()

      /// Clear cache and verify it was populated
      /// We can't directly check isCachePopulated (it's private), but we can verify
      /// that subsequent calls to extractPublicModules don't fail and use cache
      let modules = try provider.extractPublicModules()

      /// Should have at least the main module
      #expect(!modules.isEmpty)
    }

    @Test("Multiple calls use cached data", .disabled("Spawns swift process - causes test hang"))
    func multipleCallsUseCachedData() throws {
      /// This test verifies that multiple calls don't spawn multiple processes
      /// by checking that the results are consistent
      let provider = PackageInfoProvider()

      /// First call
      let modules1 = try provider.extractPublicModules()

      /// Second call should use cache
      let modules2 = try provider.extractPublicModules()

      /// Results should be identical
      #expect(modules1 == modules2)

      /// Third call with loadPackageDescription first
      let provider2 = PackageInfoProvider()
      let desc = try provider2.loadPackageDescription()
      let modules3 = try provider2.extractPublicModules()

      /// Should work and return consistent results
      #expect(!modules3.isEmpty)
      #expect(!desc.targets.isEmpty)
    }

    @Test("loadTargetPaths returns consistent results", .disabled("Spawns swift process - causes test hang"))
    func loadTargetPathsReturnsConsistentResults() throws {
      let provider = PackageInfoProvider()

      /// First call
      let paths1 = try provider.loadTargetPaths()

      /// Second call should use cache
      let paths2 = try provider.loadTargetPaths()

      /// Results should be identical
      #expect(paths1.count == paths2.count)
      for (key, value) in paths1 {
        #expect(paths2[key] == value)
      }
    }

    @Test("clearCache invalidates cached data", .disabled("Spawns swift process - causes test hang"))
    func clearCacheInvalidatesData() throws {
      let provider = PackageInfoProvider()

      /// Populate cache
      _ = try provider.extractPublicModules()

      /// Clear cache
      provider.clearCache()

      /// Should still work (will re-fetch)
      let modules = try provider.extractPublicModules()
      #expect(!modules.isEmpty)
    }
  }
}
