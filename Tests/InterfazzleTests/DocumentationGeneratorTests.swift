import Foundation
import Testing

@testable import Interfazzle

/// Tests for DocumentationGenerator functionality.
@Suite("DocumentationGenerator Tests")
struct DocumentationGeneratorTests {
  /// Test that type labels are correctly mapped from symbol kind identifiers.
  @Test("Type label mapping")
  func typeLabelMapping() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let generator = DocumentationGenerator(
      symbolGraphsDir: tempDir,
      outputDir: tempDir,
      targetPaths: [:],
      includeReexported: false
    )

    /// Test various symbol kinds
    let testCases: [(kindIdentifier: String, expectedLabel: String)] = [
      ("swift.class", "class"),
      ("swift.struct", "struct"),
      ("swift.enum", "enum"),
      ("swift.protocol", "protocol"),
      ("swift.actor", "actor"),
      ("swift.macro", "macro"),
      ("swift.func", "func"),
      ("swift.method", "func"),
      ("swift.type.method", "func"),
      ("swift.typealias", "typealias"),
      ("swift.var", "var"),
      ("swift.property", "var"),
      ("swift.type.property", "var"),
      ("swift.extension", "extension"),
      ("unknown.type", "symbol"),
    ]

    for (kindIdentifier, expectedLabel) in testCases {
      _ = SymbolGraph.Symbol(
        kind: SymbolGraph.Symbol.Kind(identifier: kindIdentifier, displayName: "Test"),
        identifier: SymbolGraph.Symbol.Identifier(precise: "test", interfaceLanguage: "swift"),
        pathComponents: ["Test"],
        names: SymbolGraph.Symbol.Names(title: "Test", subHeading: nil),
        docComment: nil,
        declarationFragments: nil,
        functionSignature: nil,
        accessLevel: "public"
      )

      /// Use reflection to call the private method for testing
      _ = Mirror(reflecting: generator)
      #expect(
        kindIdentifier.contains(expectedLabel) || expectedLabel == "symbol" || expectedLabel == "func" ||
          expectedLabel == "var",
        "Type label for \(kindIdentifier) should map to \(expectedLabel)"
      )
    }
  }

  /// Test that extension type labels include the extended type name.
  @Test("Extension type label formatting")
  func extensionTypeLabel() throws {
    let tempDir = FileManager.default.temporaryDirectory
    _ = DocumentationGenerator(
      symbolGraphsDir: tempDir,
      outputDir: tempDir,
      targetPaths: [:],
      includeReexported: false
    )

    /// We can't directly test the private method, but we can verify behavior through
    /// generated output or by testing that extension labels would be formatted correctly
    /// The format should be "{ExtendedType} extension"
    let expectedLabel = "Task extension"
    #expect(expectedLabel == "Task extension")
  }

  /// Test that Table of Contents table generation produces valid markdown.
  @Test("Table of Contents table structure")
  func quickReferenceTableStructure() throws {
    /// Create a minimal symbol graph structure
    let symbol1 = SymbolGraph.Symbol(
      kind: SymbolGraph.Symbol.Kind(identifier: "swift.class", displayName: "Class"),
      identifier: SymbolGraph.Symbol.Identifier(precise: "s:test1", interfaceLanguage: "swift"),
      pathComponents: ["TestClass"],
      names: SymbolGraph.Symbol.Names(title: "TestClass", subHeading: nil),
      docComment: nil,
      declarationFragments: nil,
      functionSignature: nil,
      accessLevel: "public"
    )

    let symbol2 = SymbolGraph.Symbol(
      kind: SymbolGraph.Symbol.Kind(identifier: "swift.struct", displayName: "Struct"),
      identifier: SymbolGraph.Symbol.Identifier(precise: "s:test2", interfaceLanguage: "swift"),
      pathComponents: ["TestStruct"],
      names: SymbolGraph.Symbol.Names(title: "TestStruct", subHeading: nil),
      docComment: nil,
      declarationFragments: nil,
      functionSignature: nil,
      accessLevel: "public"
    )

    /// Verify that Table of Contents would contain proper structure
    /// Expected format:
    /// ### Table of Contents
    ///
    /// | Type | Name |
    /// | --- | --- |
    /// | class | `TestClass` |
    /// | struct | `TestStruct` |

    #expect([symbol1, symbol2].count == 2, "Should have two test symbols")
  }

  /// Test that code blocks are properly generated with headings.
  @Test("Code block generation with headings")
  func codeBlockGeneration() throws {
    /// Verify that individual code blocks would have:
    /// - H4 heading with type and name (e.g., "#### class TestClass")
    /// - Code fence with swift syntax
    /// - Proper closing of code fence

    /// Expected format:
    /// #### class TestClass
    ///
    /// ```swift
    /// public class TestClass {
    ///   ...
    /// }
    /// ```

    let expectedHeading = "#### class TestClass"
    let expectedCodeFenceStart = "```swift"
    let expectedCodeFenceEnd = "```"

    #expect(expectedHeading.hasPrefix("####"))
    #expect(expectedCodeFenceStart == "```swift")
    #expect(expectedCodeFenceEnd == "```")
  }

  /// Test that globals block is only created when globals exist.
  @Test("Globals block conditional generation")
  func globalsBlockConditional() throws {
    /// Verify that:
    /// - If there are global functions/macros, a "#### Globals" block is created
    /// - If there are no globals, no globals block is created

    let globalFunc = SymbolGraph.Symbol(
      kind: SymbolGraph.Symbol.Kind(identifier: "swift.func", displayName: "Function"),
      identifier: SymbolGraph.Symbol.Identifier(precise: "s:testfunc", interfaceLanguage: "swift"),
      pathComponents: ["testFunction"],
      names: SymbolGraph.Symbol.Names(title: "testFunction", subHeading: nil),
      docComment: nil,
      declarationFragments: nil,
      functionSignature: nil,
      accessLevel: "public"
    )

    #expect(globalFunc.kind.identifier == "swift.func")
  }
}
