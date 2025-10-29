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
}
