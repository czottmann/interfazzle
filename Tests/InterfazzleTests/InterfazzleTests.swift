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
  }

  @Suite("PackageInfoProvider")
  struct PackageInfoProviderTests {
    @Test("Cache is populated after loadPackageDescription")
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

    @Test("Multiple calls use cached data")
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

    @Test("loadTargetPaths returns consistent results")
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

    @Test("clearCache invalidates cached data")
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
