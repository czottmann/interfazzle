## Module `Interfazzle`

### Public interface

```swift
/// Generates Markdown documentation from Swift symbol graph files.
/// 
/// This class is responsible for processing Swift symbol graphs and converting them
/// into human-readable Markdown documentation. It handles symbol filtering, hierarchy
/// organization, and proper formatting of the output documentation.
public class DocumentationGenerator {
  /// Generates documentation for all modules in the symbol graphs directory.
  /// 
  /// This is the main entry point for documentation generation. It scans the symbol
  /// graphs directory for module files and processes each one to create Markdown
  /// documentation. Modules can be filtered using the includeOnly parameter.
  /// 
  /// - Parameter includeOnly: Optional set of module names to process. If nil, all public
  ///   product modules will be processed. This allows filtering to specific modules.
  /// - Throws: Errors if the symbol graphs directory cannot be read or processing fails.
  public func generate(includeOnly: Set<String>? = nil) throws

  /// Initializes a new DocumentationGenerator instance.
  /// 
  public init(symbolGraphsDir: URL, outputDir: URL, targetPaths: [String : String], includeReexported: Bool = false)
}

/// Configuration settings for the interfazzle documentation generator.
/// 
/// This struct encapsulates all command-line options and settings that control
/// how symbol graphs are built and documentation is generated.
public struct Config: Sendable {
  /// Default configuration values for the documentation generator.
  /// 
  /// These defaults are used when no command-line arguments are provided.
  /// - symbolGraphsDir: ".build/symbol-graphs" - Standard Swift build output directory
  /// - outputDir: "docs" - Default documentation output directory
  /// - modules: nil - Document all public modules by default
  /// - generateOnly: false - Build symbol graphs before generating docs
  /// - verbose: false - Suppress detailed build output
  /// - beLenient: false - Fail on build errors unless explicitly overridden
  /// - includeReexported: false - Exclude re-exported symbols from external modules
  public static let `default`: Config

  /// Whether to continue documentation generation despite build failures.
  /// 
  /// When true, if the Swift build fails, the script will attempt to generate
  /// documentation from any existing symbol graphs instead of exiting with an error.
  public let beLenient: Bool

  /// Whether to skip the build phase and use existing symbol graphs.
  /// 
  /// When true, the script will not run `swift build` and will instead
  /// attempt to generate documentation from symbol graphs that already exist
  /// in the symbolGraphsDir.
  public let generateOnly: Bool

  /// Whether to include symbols that are re-exported from external modules.
  /// 
  /// When false (default), symbols from external frameworks (via @_exported import)
  /// are filtered out to focus on the package's own API. When true, these symbols
  /// are included in the generated documentation.
  public let includeReexported: Bool

  /// Optional set of module names to include in documentation generation.
  /// 
  /// When nil, all public product modules will be documented. When specified,
  /// only the modules in this set will be processed.
  public let modules: Set<String>?

  /// Directory path where generated Markdown documentation files will be written.
  /// 
  /// Each module will generate a separate .md file in this directory.
  public let outputDir: String

  /// Directory path where Swift symbol graph files are located or will be generated.
  /// 
  /// Symbol graphs contain the structural information about Swift modules that
  /// is used to generate API documentation.
  public let symbolGraphsDir: String

  /// Whether to display full build output from Swift compilation.
  /// 
  /// When false (default), build output is captured and only shown on error.
  /// When true, all build output is displayed in real-time.
  public let verbose: Bool

  /// Initializes a new Config instance.
  /// 
  public init(symbolGraphsDir: String, outputDir: String, modules: Set<String>?, generateOnly: Bool, verbose: Bool, beLenient: Bool, includeReexported: Bool)
}

/// Formats Swift declaration fragments into readable strings.
/// 
/// This struct provides utilities for converting symbol graph declaration fragments
/// into properly formatted Swift code strings for documentation output.
public struct DeclarationFormatter {
  /// Extracts a readable type name from a precise symbol identifier.
  /// 
  /// This method attempts to demangle Swift symbol identifiers and map them to
  /// human-readable type names. It handles Objective-C symbols, standard library types,
  /// and uses swift-demangle for complex Swift symbols.
  /// 
  /// - Parameter preciseIdentifier: The precise identifier from a symbol graph.
  /// - Returns: A readable type name if extraction succeeds, nil otherwise.
  public func extractTypeName(from preciseIdentifier: String) -> String?

  /// Formats declaration fragments into a readable string.
  /// 
  /// This function filters out unwanted keywords/attributes and optionally adds
  /// a public modifier if not already present.
  /// 
  public func formatDeclaration(fragments: [SymbolGraph.Symbol.DeclarationFragment], addPublic: Bool) -> String

  /// Initializes a new DeclarationFormatter.
  public init()
}

/// Utilities for formatting Markdown content.
/// 
/// This struct provides helper functions for processing Markdown text,
/// particularly for adjusting heading levels and formatting documentation comments.
public struct MarkdownFormatter {
  /// Adjusts heading levels in markdown content to fit within documentation hierarchy.
  /// 
  /// This function ensures that markdown headings are properly nested within the
  /// generated documentation by shifting all heading levels so the highest level
  /// becomes H3 (to fit under the main module H2 heading).
  /// 
  /// - Parameter markdown: The markdown content to adjust.
  /// - Returns: Markdown with adjusted heading levels.
  public func adjustHeadingLevels(in markdown: String) -> String

  /// Formats a documentation comment for output.
  /// 
  /// This function converts a symbol's doc comment into formatted Markdown with
  /// appropriate indentation and filters out parameter sections.
  /// 
  public func formatDocComment(_ docComment: SymbolGraph.Symbol.DocComment?, indent: String = "") -> String

  /// Initializes a new MarkdownFormatter.
  public init()
}

/// Extracts public module names from a Swift package.
/// 
/// This class provides functionality to query a Swift package and discover
/// which modules are exposed as public products that should be documented.
public struct ModuleExtractor {
  /// Errors that can occur during module extraction.
  public enum ExtractionError: Sendable, LocalizedError, Error {
    /// A localized message describing what error occurred.
    public var errorDescription: String? { get }

    public case invalidJSON

    public case swiftCommandFailed
  }

  /// Extracts public module names from the Swift package description.
  /// 
  /// This function runs `swift package describe --type json` to get the package
  /// information and extracts the target names from all products.
  /// 
  /// - Returns: An array of module names that are exposed as products in the package.
  /// - Throws: `ExtractionError` if the command fails or JSON parsing fails.
  public func extractPublicModules() throws -> [String]

  /// Initializes a new ModuleExtractor.
  public init()
}

/// Represents the structure of a Swift package description.
/// 
/// This struct is used to parse the JSON output from `swift package describe --type json`
/// and extract information about package targets and their file system locations.
public struct PackageDescription: Decodable, Encodable {
  /// Represents a build target within a Swift package.
  /// 
  /// A target corresponds to a module that can be built as part of the package.
  /// Each target has a name and a file system path where its source files are located.
  public struct Target: Decodable, Encodable {
    /// The name of the build target/module.
    /// 
    /// This is the identifier used to reference the target within the package
    /// and corresponds to the module name that can be imported in Swift code.
    public let name: String

    /// The relative file system path to the target's source directory.
    /// 
    /// This path is relative to the package root and points to the directory
    /// containing the target's Swift source files.
    public let path: String

    /// Creates a new instance by decoding from the given decoder.
    /// 
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    /// 
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: any Decoder) throws
  }

  /// Array of all build targets defined in the package.
  /// 
  /// This includes both library and executable targets that are part of the package.
  public let targets: [Target]

  /// Creates a new instance by decoding from the given decoder.
  /// 
  /// This initializer throws an error if reading from the decoder fails, or
  /// if the data read is corrupted or otherwise invalid.
  /// 
  /// - Parameter decoder: The decoder to read data from.
  public init(from decoder: any Decoder) throws
}

/// Loads package description and extracts target path information.
/// 
/// This class provides functionality to query a Swift package and discover
/// the file system locations of targets for README integration.
public struct PackageInfoLoader {
  /// Errors that can occur during package info loading.
  public enum LoadError: Error, LocalizedError, Sendable {
    /// A localized message describing what error occurred.
    public var errorDescription: String? { get }

    public case invalidJSON

    public case swiftCommandFailed
  }

  /// Initializes a new PackageInfoLoader.
  public init()

  /// Loads package description and extracts target path information.
  /// 
  /// This function runs `swift package describe --type json` to get information
  /// about the package targets and their file system locations. The returned
  /// mapping is used to locate README.md files within each target directory.
  /// 
  /// - Returns: Dictionary mapping target names to their relative file system paths.
  /// - Throws: `LoadError` if the command fails or JSON parsing fails.
  public func loadPackageDescription() throws -> [String : String]
}

/// Validates the Swift package environment.
/// 
/// This class provides functionality to verify that the current directory
/// contains a valid Swift package before attempting to generate documentation.
public struct PackageValidator {
  /// Errors that can occur during package validation.
  public enum ValidationError: Sendable, Error, LocalizedError {
    /// A localized message describing what error occurred.
    public var errorDescription: String? { get }

    public case packageSwiftNotFound
  }

  /// Initializes a new PackageValidator.
  public init()

  /// Validates that Package.swift exists in the current directory.
  /// 
  /// - Throws: `ValidationError.packageSwiftNotFound` if Package.swift is not found.
  public func validate() throws
}

/// Represents a Swift symbol graph file structure.
/// 
/// Symbol graphs are JSON files generated by the Swift compiler that contain
/// information about the symbols (types, functions, properties, etc.) in a module,
/// their relationships, and documentation comments.
public struct SymbolGraph: Encodable, Decodable {
  /// Represents the module information in a symbol graph.
  /// 
  /// This contains basic metadata about the Swift module that the symbol graph describes.
  public struct Module: Decodable, Encodable {
    /// The name of the module.
    /// 
    /// This corresponds to the module name that can be imported in Swift code
    /// and typically matches the target name in Package.swift.
    public let name: String

    /// Creates a new instance by decoding from the given decoder.
    /// 
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    /// 
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: any Decoder) throws
  }

  /// Represents a relationship between two symbols.
  /// 
  /// This captures various types of relationships such as inheritance,
  /// conformance, membership, and other connections between symbols.
  public struct Relationship: Decodable, Encodable {
    /// The kind of relationship.
    /// 
    /// Examples include "inheritsFrom", "conformsTo", "memberOf", "overrideOf", etc.
    public let kind: String

    /// The precise identifier of the source symbol in this relationship.
    /// 
    /// This refers to the symbol that is the source of the relationship.
    public let source: String

    /// The precise identifier of the target symbol in this relationship.
    /// 
    /// This refers to the symbol that is the target of the relationship.
    public let target: String

    /// Creates a new instance by decoding from the given decoder.
    /// 
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    /// 
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: any Decoder) throws
  }

  /// Represents a Swift symbol (type, function, property, etc.) in the symbol graph.
  /// 
  /// This is the core data structure that contains all information about a particular
  /// Swift symbol, including its declaration, documentation, and metadata.
  public struct Symbol: Decodable, Encodable {
    /// Represents a fragment of a symbol's declaration.
    /// 
    /// Declarations are broken down into fragments to allow for structured
    /// processing and formatting of symbol signatures.
    public struct DeclarationFragment: Decodable, Encodable {
      /// The kind of declaration fragment.
      /// 
      /// This indicates what type of token this fragment represents,
      /// such as "keyword", "identifier", "text", "type", etc.
      public let kind: String

      /// The actual text/spelling of this declaration fragment.
      /// 
      /// This contains the literal text that appears in the source code.
      public let spelling: String

      /// Creates a new instance by decoding from the given decoder.
      /// 
      /// This initializer throws an error if reading from the decoder fails, or
      /// if the data read is corrupted or otherwise invalid.
      /// 
      /// - Parameter decoder: The decoder to read data from.
      public init(from decoder: any Decoder) throws
    }

    /// Represents documentation comments associated with a symbol.
    /// 
    /// This contains the structured documentation comments from the source code,
    /// broken down into individual lines for processing.
    public struct DocComment: Decodable, Encodable {
      /// Represents a single line of documentation comment.
      /// 
      /// Each line is stored separately to preserve formatting and allow
      /// for structured processing of documentation content.
      public struct Line: Encodable, Decodable {
        /// The text content of this documentation line.
        /// 
        /// This contains the actual comment text from the source code.
        public let text: String

        /// Creates a new instance by decoding from the given decoder.
        /// 
        /// This initializer throws an error if reading from the decoder fails, or
        /// if the data read is corrupted or otherwise invalid.
        /// 
        /// - Parameter decoder: The decoder to read data from.
        public init(from decoder: any Decoder) throws
      }

      /// Array of lines that make up the complete documentation comment.
      /// 
      /// This preserves the original line-by-line structure of the documentation.
      public let lines: [Line]

      /// Creates a new instance by decoding from the given decoder.
      /// 
      /// This initializer throws an error if reading from the decoder fails, or
      /// if the data read is corrupted or otherwise invalid.
      /// 
      /// - Parameter decoder: The decoder to read data from.
      public init(from decoder: any Decoder) throws
    }

    /// Represents the signature of a function symbol.
    /// 
    /// This contains detailed information about function parameters and return types,
    /// broken down into structured declaration fragments.
    public struct FunctionSignature: Encodable, Decodable {
      /// Represents a parameter in a function signature.
      /// 
      /// This contains the parameter name and its type information
      /// as declaration fragments for structured processing.
      public struct Parameter: Encodable, Decodable {
        /// Declaration fragments describing the parameter's type.
        /// 
        /// This contains the type information and any modifiers for the parameter,
        /// broken down into structured fragments.
        public let declarationFragments: [DeclarationFragment]?

        /// The name of the parameter.
        /// 
        /// This is the identifier used for the parameter in the function signature.
        public let name: String

        /// Creates a new instance by decoding from the given decoder.
        /// 
        /// This initializer throws an error if reading from the decoder fails, or
        /// if the data read is corrupted or otherwise invalid.
        /// 
        /// - Parameter decoder: The decoder to read data from.
        public init(from decoder: any Decoder) throws
      }

      /// Array of parameters for this function.
      /// 
      /// This may be nil for functions that take no parameters.
      public let parameters: [Parameter]?

      /// Declaration fragments describing the return type.
      /// 
      /// This contains the return type information broken down into fragments.
      /// May be nil for functions without explicit return types (Void).
      public let returns: [DeclarationFragment]?

      /// Creates a new instance by decoding from the given decoder.
      /// 
      /// This initializer throws an error if reading from the decoder fails, or
      /// if the data read is corrupted or otherwise invalid.
      /// 
      /// - Parameter decoder: The decoder to read data from.
      public init(from decoder: any Decoder) throws
    }

    /// Represents a unique identifier for a symbol.
    /// 
    /// This provides a way to uniquely reference symbols across different
    /// symbol graphs and within relationships.
    public struct Identifier: Decodable, Encodable {
      /// The interface language for this symbol.
      /// 
      /// For Swift symbols, this is typically "swift". This allows symbol graphs
      /// to potentially contain symbols from different languages.
      public let interfaceLanguage: String

      /// The precise identifier that uniquely identifies this symbol.
      /// 
      /// This is a mangled name that includes the full module path and symbol name,
      /// used for precise symbol identification and relationship tracking.
      public let precise: String

      /// Creates a new instance by decoding from the given decoder.
      /// 
      /// This initializer throws an error if reading from the decoder fails, or
      /// if the data read is corrupted or otherwise invalid.
      /// 
      /// - Parameter decoder: The decoder to read data from.
      public init(from decoder: any Decoder) throws
    }

    /// Represents the kind of symbol (class, struct, function, etc.).
    /// 
    /// The identifier follows a specific naming convention used by the Swift compiler
    /// to categorize different types of symbols.
    public struct Kind: Decodable, Encodable {
      /// The human-readable display name for the symbol kind.
      /// 
      /// This is a more user-friendly representation of the symbol type.
      public let displayName: String

      /// The machine-readable identifier for the symbol kind.
      /// 
      /// Examples include "swift.class", "swift.struct", "swift.func", "swift.enum", etc.
      public let identifier: String

      /// Creates a new instance by decoding from the given decoder.
      /// 
      /// This initializer throws an error if reading from the decoder fails, or
      /// if the data read is corrupted or otherwise invalid.
      /// 
      /// - Parameter decoder: The decoder to read data from.
      public init(from decoder: any Decoder) throws
    }

    /// Represents the various names associated with a symbol.
    /// 
    /// This includes the primary title and any subheading information
    /// that might be used for display purposes.
    public struct Names: Decodable, Encodable {
      /// Optional subheading fragments for the symbol.
      /// 
      /// This can contain additional type information or other context
      /// that appears after the main symbol name.
      public let subHeading: [DeclarationFragment]?

      /// The primary title/name of the symbol.
      /// 
      /// This is the main name used to identify the symbol in documentation.
      public let title: String

      /// Creates a new instance by decoding from the given decoder.
      /// 
      /// This initializer throws an error if reading from the decoder fails, or
      /// if the data read is corrupted or otherwise invalid.
      /// 
      /// - Parameter decoder: The decoder to read data from.
      public init(from decoder: any Decoder) throws
    }

    /// The access level of this symbol.
    /// 
    /// This indicates the visibility level (public, internal, private, etc.).
    /// String value such as "public", "internal", "private", "fileprivate", "open".
    public let accessLevel: String

    /// Declaration fragments that make up the symbol's signature.
    /// 
    /// This provides the complete declaration broken down into structured tokens.
    /// May be nil for some types of symbols.
    public let declarationFragments: [DeclarationFragment]?

    /// Documentation comments associated with this symbol.
    /// 
    /// This contains the structured documentation from the source code.
    /// May be nil if the symbol has no documentation.
    public let docComment: DocComment?

    /// Function signature information for function symbols.
    /// 
    /// This contains detailed parameter and return type information.
    /// Only applicable to function/method symbols.
    public let functionSignature: FunctionSignature?

    /// The unique identifier for this symbol.
    /// 
    /// This is used to reference this symbol in relationships and for
    /// cross-symbol graph references.
    public let identifier: Identifier

    /// The kind of symbol (class, struct, function, etc.).
    /// 
    /// This determines how the symbol should be categorized and displayed.
    public let kind: Kind

    /// The names and display information for this symbol.
    /// 
    /// This includes the title and any subheading information.
    public let names: Names

    /// The path components that form the symbol's full path.
    /// 
    /// This represents the hierarchical path to the symbol, such as
    /// ["MyClass", "myMethod"] for a method inside a class.
    public let pathComponents: [String]

    /// Creates a new instance by decoding from the given decoder.
    /// 
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    /// 
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: any Decoder) throws
  }

  /// Information about the module this symbol graph describes.
  /// 
  /// This contains the basic module metadata.
  public let module: Module

  /// Array of relationships between symbols in this module.
  /// 
  /// This captures inheritance hierarchies, protocol conformances,
  /// type memberships, and other symbol relationships.
  /// May be nil if no relationships are defined.
  public let relationships: [Relationship]?

  /// Array of all symbols defined in this module.
  /// 
  /// This includes all types, functions, properties, and other symbols
  /// that are part of the module's public API.
  public let symbols: [Symbol]

  /// Creates a new instance by decoding from the given decoder.
  /// 
  /// This initializer throws an error if reading from the decoder fails, or
  /// if the data read is corrupted or otherwise invalid.
  /// 
  /// - Parameter decoder: The decoder to read data from.
  public init(from decoder: any Decoder) throws
}

/// Builds symbol graphs for a Swift package.
/// 
/// This class provides functionality to compile a Swift package with symbol graph
/// generation enabled, producing the JSON files needed for documentation generation.
public struct SymbolGraphBuilder {
  /// Errors that can occur during symbol graph building.
  public enum BuildError: Error, LocalizedError, Sendable {
    /// A localized message describing what error occurred.
    public var errorDescription: String? { get }

    public case buildFailed(exitCode: Int32, output: String)
  }

  /// Builds symbol graphs for the Swift package.
  /// 
  /// This function runs `swift build` with symbol graph generation flags and creates
  /// the output directory if needed. Build output is captured and only shown on error
  /// unless verbose mode is enabled.
  /// 
  public func build(symbolGraphsDir: String, verbose: Bool) throws

  /// Initializes a new SymbolGraphBuilder.
  public init()
}
```

<!-- Generated by interfazzle.swift on 2025-10-29 12:20:38 +0100 -->
