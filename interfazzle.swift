#!/usr/bin/env swift

import Foundation

// MARK: - Config

/// Configuration settings for the interfazzle documentation generator.
///
/// This struct encapsulates all command-line options and settings that control
/// how symbol graphs are built and documentation is generated.
struct Config {
  // MARK: - Static Properties

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
  static let `default` = Config(
    symbolGraphsDir: ".build/symbol-graphs",
    outputDir: "docs",
    modules: nil,
    generateOnly: false,
    verbose: false,
    beLenient: false,
    includeReexported: false
  )

  // MARK: - Properties

  /// Directory path where Swift symbol graph files are located or will be generated.
  ///
  /// Symbol graphs contain the structural information about Swift modules that
  /// is used to generate API documentation.
  let symbolGraphsDir: String

  /// Directory path where generated Markdown documentation files will be written.
  ///
  /// Each module will generate a separate .md file in this directory.
  let outputDir: String

  /// Optional set of module names to include in documentation generation.
  ///
  /// When nil, all public product modules will be documented. When specified,
  /// only the modules in this set will be processed.
  let modules: Set<String>?

  /// Whether to skip the build phase and use existing symbol graphs.
  ///
  /// When true, the script will not run `swift build` and will instead
  /// attempt to generate documentation from symbol graphs that already exist
  /// in the symbolGraphsDir.
  let generateOnly: Bool

  /// Whether to display full build output from Swift compilation.
  ///
  /// When false (default), build output is captured and only shown on error.
  /// When true, all build output is displayed in real-time.
  let verbose: Bool

  /// Whether to continue documentation generation despite build failures.
  ///
  /// When true, if the Swift build fails, the script will attempt to generate
  /// documentation from any existing symbol graphs instead of exiting with an error.
  let beLenient: Bool

  /// Whether to include symbols that are re-exported from external modules.
  ///
  /// When false (default), symbols from external frameworks (via @_exported import)
  /// are filtered out to focus on the package's own API. When true, these symbols
  /// are included in the generated documentation.
  let includeReexported: Bool
}

// MARK: - CLI Argument Parsing

/// Parses command line arguments and returns a configuration object.
///
/// - Returns: A Config object containing parsed settings, or nil if help was requested.
///   The function handles both flags (like --verbose) and positional arguments
///   (symbol graphs directory, output directory, modules list).
func parseArguments() -> Config? {
  var config = Config.default
  var positionalArgs: [String] = []

  var i = 1
  while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]

    switch arg {
      case "--generate-only":
        config = Config(
          symbolGraphsDir: config.symbolGraphsDir,
          outputDir: config.outputDir,
          modules: config.modules,
          generateOnly: true,
          verbose: config.verbose,
          beLenient: config.beLenient,
          includeReexported: config.includeReexported
        )

      case "--verbose":
        config = Config(
          symbolGraphsDir: config.symbolGraphsDir,
          outputDir: config.outputDir,
          modules: config.modules,
          generateOnly: config.generateOnly,
          verbose: true,
          beLenient: config.beLenient,
          includeReexported: config.includeReexported
        )

      case "--be-lenient":
        config = Config(
          symbolGraphsDir: config.symbolGraphsDir,
          outputDir: config.outputDir,
          modules: config.modules,
          generateOnly: config.generateOnly,
          verbose: config.verbose,
          beLenient: true,
          includeReexported: config.includeReexported
        )

      case "--include-reexported":
        config = Config(
          symbolGraphsDir: config.symbolGraphsDir,
          outputDir: config.outputDir,
          modules: config.modules,
          generateOnly: config.generateOnly,
          verbose: config.verbose,
          beLenient: config.beLenient,
          includeReexported: true
        )

      case "--help",
           "-h":
        printUsage()
        return nil

      default:
        if arg.hasPrefix("--") {
          print("❌ Error: Unknown flag '\(arg)'")
          printUsage()
          return nil
        }
        positionalArgs.append(arg)
    }
    i += 1
  }

  // Process positional arguments
  if positionalArgs.count > 3 {
    print("❌ Error: Too many arguments")
    printUsage()
    return nil
  }

  let symbolGraphsDir = positionalArgs.count > 0 ? positionalArgs[0] : config.symbolGraphsDir
  let outputDir = positionalArgs.count > 1 ? positionalArgs[1] : config.outputDir
  let modules: Set<String>? = positionalArgs.count > 2
    ? Set(positionalArgs[2].split(separator: ",").map { String($0) })
    : nil

  return Config(
    symbolGraphsDir: symbolGraphsDir,
    outputDir: outputDir,
    modules: modules,
    generateOnly: config.generateOnly,
    verbose: config.verbose,
    beLenient: config.beLenient,
    includeReexported: config.includeReexported
  )
}

/// Prints usage information to standard output.
///
/// Displays the command line interface documentation including available flags,
/// arguments, examples, and exit codes. This function is called when the user
/// requests help with --help or -h flags.
func printUsage() {
  print("""
  Usage: interfazzle.swift [FLAGS] [SYMBOL_GRAPHS_DIR] [OUTPUT_DIR] [MODULES]

  Generate API documentation from Swift symbol graphs.

  FLAGS:
    --generate-only      Skip build phase, use existing symbol graphs
    --verbose            Show full swift build output
    --be-lenient         On build failure, try generating from existing graphs
    --include-reexported Include re-exported symbols in documentation
    --help, -h           Show this help message

  ARGUMENTS (all optional):
    SYMBOL_GRAPHS_DIR  Directory for symbol graphs (default: .build/symbol-graphs)
    OUTPUT_DIR         Output directory for docs (default: docs)
    MODULES            Comma-separated module list (default: all public modules)

  EXAMPLES:
    interfazzle.swift
    interfazzle.swift --verbose
    interfazzle.swift --generate-only
    interfazzle.swift .build/symbol-graphs docs
    interfazzle.swift .build/symbol-graphs docs "Licensing,Trialling"

  EXIT CODES:
    0  Success
    1  Validation error (e.g., Package.swift not found)
    2  Build error (when not using --be-lenient)
    3  Documentation generation error
  """)
}

// MARK: - Orchestration Functions

/// Validates that Package.swift exists in the current directory.
///
/// - Throws: An NSError with code 1 if Package.swift is not found in the current directory.
///   This is the first validation step before attempting to generate documentation.
func validatePackageSwift() throws {
  let fm = FileManager.default
  guard fm.fileExists(atPath: "./Package.swift") else {
    throw NSError(
      domain: "DocumentationGenerator",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey: """
        ❌ Error: Package.swift not found in current directory
           Please run this script from the root of a Swift package
        """,
      ]
    )
  }
}

/// Extracts public module names from the Swift package description.
///
/// - Returns: An array of module names that are exposed as products in the package.
///   This function runs `swift package describe --type json` to get the package
///   information and extracts the target names from all products.
/// - Throws: An NSError if the swift package describe command fails.
func extractPublicModules() throws -> [String] {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
  process.arguments = ["package", "describe", "--type", "json"]

  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = Pipe()

  try process.run()
  process.waitUntilExit()

  guard process.terminationStatus == 0 else {
    throw NSError(
      domain: "DocumentationGenerator",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Failed to run 'swift package describe'"]
    )
  }

  let data = pipe.fileHandleForReading.readDataToEndOfFile()

  struct PackageInfo: Codable {
    struct Product: Codable {
      let targets: [String]
    }

    let products: [Product]
  }

  let packageInfo = try JSONDecoder().decode(PackageInfo.self, from: data)

  // Get all unique targets from products (these are the public modules)
  var modules = Set<String>()
  for product in packageInfo.products {
    modules.formUnion(product.targets)
  }

  return modules.sorted()
}

/// Builds symbol graphs for the Swift package.
///
/// - Parameters:
///   - symbolGraphsDir: The directory where symbol graph files should be generated.
///   - verbose: Whether to show full build output or suppress it (default behavior).
///
/// This function runs `swift build` with symbol graph generation flags and creates
/// the output directory if needed. Build output is captured and only shown on error
/// unless verbose mode is enabled.
/// - Throws: An NSError with code 2 if the build fails with a non-zero exit status.
func buildSymbolGraphs(symbolGraphsDir: String, verbose: Bool) throws {
  print("🔨 Building symbol graphs...")

  // Create directory if needed
  let fm = FileManager.default
  try fm.createDirectory(atPath: symbolGraphsDir, withIntermediateDirectories: true)

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
  process.arguments = [
    "build",
    "-Xswiftc", "-emit-symbol-graph",
    "-Xswiftc", "-emit-symbol-graph-dir",
    "-Xswiftc", symbolGraphsDir,
  ]

  if verbose {
    // Stream output in real-time
    try process.run()
    process.waitUntilExit()
  }
  else {
    // Capture output, only show on error
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

      var output = ""
      if let stdout = String(data: outputData, encoding: .utf8), !stdout.isEmpty {
        output += stdout
      }
      if let stderr = String(data: errorData, encoding: .utf8), !stderr.isEmpty {
        output += stderr
      }

      throw NSError(
        domain: "DocumentationGenerator",
        code: 2,
        userInfo: [
          NSLocalizedDescriptionKey: "Build failed with exit code \(process.terminationStatus)",
          NSLocalizedFailureReasonErrorKey: output,
        ]
      )
    }
  }

  guard process.terminationStatus == 0 else {
    throw NSError(
      domain: "DocumentationGenerator",
      code: 2,
      userInfo: [NSLocalizedDescriptionKey: "Build failed with exit code \(process.terminationStatus)"]
    )
  }
}

// MARK: - PackageDescription

/// Represents the structure of a Swift package description.
///
/// This struct is used to parse the JSON output from `swift package describe --type json`
/// and extract information about package targets and their file system locations.
struct PackageDescription: Codable {
  // MARK: - Nested Types

  /// Represents a build target within a Swift package.
  ///
  /// A target corresponds to a module that can be built as part of the package.
  /// Each target has a name and a file system path where its source files are located.
  struct Target: Codable {
    /// The name of the build target/module.
    ///
    /// This is the identifier used to reference the target within the package
    /// and corresponds to the module name that can be imported in Swift code.
    let name: String

    /// The relative file system path to the target's source directory.
    ///
    /// This path is relative to the package root and points to the directory
    /// containing the target's Swift source files.
    let path: String
  }

  // MARK: - Properties

  /// Array of all build targets defined in the package.
  ///
  /// This includes both library and executable targets that are part of the package.
  let targets: [Target]
}

// MARK: - SymbolGraph

/// Represents a Swift symbol graph file structure.
///
/// Symbol graphs are JSON files generated by the Swift compiler that contain
/// information about the symbols (types, functions, properties, etc.) in a module,
/// their relationships, and documentation comments.
struct SymbolGraph: Codable {
  // MARK: - Nested Types

  /// Represents the module information in a symbol graph.
  ///
  /// This contains basic metadata about the Swift module that the symbol graph describes.
  struct Module: Codable {
    /// The name of the module.
    ///
    /// This corresponds to the module name that can be imported in Swift code
    /// and typically matches the target name in Package.swift.
    let name: String
  }

  /// Represents a Swift symbol (type, function, property, etc.) in the symbol graph.
  ///
  /// This is the core data structure that contains all information about a particular
  /// Swift symbol, including its declaration, documentation, and metadata.
  struct Symbol: Codable {
    // MARK: - Nested Types

    /// Represents the kind of symbol (class, struct, function, etc.).
    ///
    /// The identifier follows a specific naming convention used by the Swift compiler
    /// to categorize different types of symbols.
    struct Kind: Codable {
      /// The machine-readable identifier for the symbol kind.
      ///
      /// Examples include "swift.class", "swift.struct", "swift.func", "swift.enum", etc.
      let identifier: String

      /// The human-readable display name for the symbol kind.
      ///
      /// This is a more user-friendly representation of the symbol type.
      let displayName: String
    }

    /// Represents a unique identifier for a symbol.
    ///
    /// This provides a way to uniquely reference symbols across different
    /// symbol graphs and within relationships.
    struct Identifier: Codable {
      /// The precise identifier that uniquely identifies this symbol.
      ///
      /// This is a mangled name that includes the full module path and symbol name,
      /// used for precise symbol identification and relationship tracking.
      let precise: String

      /// The interface language for this symbol.
      ///
      /// For Swift symbols, this is typically "swift". This allows symbol graphs
      /// to potentially contain symbols from different languages.
      let interfaceLanguage: String
    }

    /// Represents the various names associated with a symbol.
    ///
    /// This includes the primary title and any subheading information
    /// that might be used for display purposes.
    struct Names: Codable {
      /// The primary title/name of the symbol.
      ///
      /// This is the main name used to identify the symbol in documentation.
      let title: String

      /// Optional subheading fragments for the symbol.
      ///
      /// This can contain additional type information or other context
      /// that appears after the main symbol name.
      let subHeading: [DeclarationFragment]?
    }

    /// Represents documentation comments associated with a symbol.
    ///
    /// This contains the structured documentation comments from the source code,
    /// broken down into individual lines for processing.
    struct DocComment: Codable {
      // MARK: - Nested Types

      /// Represents a single line of documentation comment.
      ///
      /// Each line is stored separately to preserve formatting and allow
      /// for structured processing of documentation content.
      struct Line: Codable {
        /// The text content of this documentation line.
        ///
        /// This contains the actual comment text from the source code.
        let text: String
      }

      // MARK: - Properties

      /// Array of lines that make up the complete documentation comment.
      ///
      /// This preserves the original line-by-line structure of the documentation.
      let lines: [Line]
    }

    /// Represents a fragment of a symbol's declaration.
    ///
    /// Declarations are broken down into fragments to allow for structured
    /// processing and formatting of symbol signatures.
    struct DeclarationFragment: Codable {
      /// The kind of declaration fragment.
      ///
      /// This indicates what type of token this fragment represents,
      /// such as "keyword", "identifier", "text", "type", etc.
      let kind: String

      /// The actual text/spelling of this declaration fragment.
      ///
      /// This contains the literal text that appears in the source code.
      let spelling: String
    }

    /// Represents the signature of a function symbol.
    ///
    /// This contains detailed information about function parameters and return types,
    /// broken down into structured declaration fragments.
    struct FunctionSignature: Codable {
      // MARK: - Nested Types

      /// Represents a parameter in a function signature.
      ///
      /// This contains the parameter name and its type information
      /// as declaration fragments for structured processing.
      struct Parameter: Codable {
        /// The name of the parameter.
        ///
        /// This is the identifier used for the parameter in the function signature.
        let name: String

        /// Declaration fragments describing the parameter's type.
        ///
        /// This contains the type information and any modifiers for the parameter,
        /// broken down into structured fragments.
        let declarationFragments: [DeclarationFragment]?
      }

      // MARK: - Properties

      /// Array of parameters for this function.
      ///
      /// This may be nil for functions that take no parameters.
      let parameters: [Parameter]?

      /// Declaration fragments describing the return type.
      ///
      /// This contains the return type information broken down into fragments.
      /// May be nil for functions without explicit return types (Void).
      let returns: [DeclarationFragment]?
    }

    // MARK: - Properties

    /// The kind of symbol (class, struct, function, etc.).
    ///
    /// This determines how the symbol should be categorized and displayed.
    let kind: Kind

    /// The unique identifier for this symbol.
    ///
    /// This is used to reference this symbol in relationships and for
    /// cross-symbol graph references.
    let identifier: Identifier

    /// The path components that form the symbol's full path.
    ///
    /// This represents the hierarchical path to the symbol, such as
    /// ["MyClass", "myMethod"] for a method inside a class.
    let pathComponents: [String]

    /// The names and display information for this symbol.
    ///
    /// This includes the title and any subheading information.
    let names: Names

    /// Documentation comments associated with this symbol.
    ///
    /// This contains the structured documentation from the source code.
    /// May be nil if the symbol has no documentation.
    let docComment: DocComment?

    /// Declaration fragments that make up the symbol's signature.
    ///
    /// This provides the complete declaration broken down into structured tokens.
    /// May be nil for some types of symbols.
    let declarationFragments: [DeclarationFragment]?

    /// Function signature information for function symbols.
    ///
    /// This contains detailed parameter and return type information.
    /// Only applicable to function/method symbols.
    let functionSignature: FunctionSignature?

    /// The access level of this symbol.
    ///
    /// This indicates the visibility level (public, internal, private, etc.).
    /// String value such as "public", "internal", "private", "fileprivate", "open".
    let accessLevel: String
  }

  /// Represents a relationship between two symbols.
  ///
  /// This captures various types of relationships such as inheritance,
  /// conformance, membership, and other connections between symbols.
  struct Relationship: Codable {
    /// The kind of relationship.
    ///
    /// Examples include "inheritsFrom", "conformsTo", "memberOf", "overrideOf", etc.
    let kind: String

    /// The precise identifier of the source symbol in this relationship.
    ///
    /// This refers to the symbol that is the source of the relationship.
    let source: String

    /// The precise identifier of the target symbol in this relationship.
    ///
    /// This refers to the symbol that is the target of the relationship.
    let target: String
  }

  // MARK: - Properties

  /// Information about the module this symbol graph describes.
  ///
  /// This contains the basic module metadata.
  let module: Module

  /// Array of all symbols defined in this module.
  ///
  /// This includes all types, functions, properties, and other symbols
  /// that are part of the module's public API.
  let symbols: [Symbol]

  /// Array of relationships between symbols in this module.
  ///
  /// This captures inheritance hierarchies, protocol conformances,
  /// type memberships, and other symbol relationships.
  /// May be nil if no relationships are defined.
  let relationships: [Relationship]?
}

// MARK: - DocumentationGenerator

/// Generates Markdown documentation from Swift symbol graph files.
///
/// This class is responsible for processing Swift symbol graphs and converting them
/// into human-readable Markdown documentation. It handles symbol filtering, hierarchy
/// organization, and proper formatting of the output documentation.
class DocumentationGenerator {
  // MARK: - Properties

  /// The directory containing symbol graph files to process.
  ///
  /// This directory should contain .symbols.json files generated by the Swift compiler.
  private let symbolGraphsDir: URL

  /// The directory where generated Markdown documentation will be written.
  ///
  /// Each module will generate a separate .md file in this directory.
  private let outputDir: URL

  /// Mapping of target names to their file system paths.
  ///
  /// This is used to locate README.md files within each target's directory
  /// and include them in the generated documentation.
  private let targetPaths: [String: String] // target name -> path

  /// Whether to include re-exported symbols in the documentation.
  ///
  /// When false, symbols from external modules are filtered out to focus
  /// on the package's own API. When true, all symbols are included.
  private let includeReexported: Bool

  // MARK: - Lifecycle

  /// Initializes a new DocumentationGenerator instance.
  ///
  /// - Parameters:
  ///   - symbolGraphsDir: The directory containing symbol graph files.
  ///   - outputDir: The directory where documentation will be written.
  ///   - targetPaths: Mapping of target names to their source directory paths.
  ///   - includeReexported: Whether to include re-exported symbols from external modules.
  init(symbolGraphsDir: URL, outputDir: URL, targetPaths: [String: String], includeReexported: Bool = false) {
    self.symbolGraphsDir = symbolGraphsDir
    self.outputDir = outputDir
    self.targetPaths = targetPaths
    self.includeReexported = includeReexported
  }

  // MARK: - Functions

  /// Generates documentation for all modules in the symbol graphs directory.
  ///
  /// This is the main entry point for documentation generation. It scans the symbol
  /// graphs directory for module files and processes each one to create Markdown
  /// documentation. Modules can be filtered using the includeOnly parameter.
  ///
  /// - Parameter includeOnly: Optional set of module names to process. If nil, all public
  ///   product modules will be processed. This allows filtering to specific modules.
  /// - Throws: Errors if the symbol graphs directory cannot be read or processing fails.
  func generate(includeOnly: Set<String>? = nil) throws {
    let fm = FileManager.default

    guard let files = try? fm.contentsOfDirectory(atPath: symbolGraphsDir.path) else {
      print("Error: Cannot read symbol graphs directory")
      return
    }

    // Process only main module files (not @Module.symbols.json)
    let mainFiles = files.filter { $0.hasSuffix(".symbols.json") && !$0.contains("@") }

    for file in mainFiles {
      let moduleName = file.replacingOccurrences(of: ".symbols.json", with: "")

      // Filter to included modules if specified
      if let includeOnly, !includeOnly.contains(moduleName) {
        continue
      }

      try processModule(moduleName: moduleName, fileName: file)
    }
  }

  /// Detects if a symbol is re-exported from another module.
  ///
  /// This method filters out symbols that come from external frameworks through
  /// @_exported import statements. It examines the precise identifiers to determine
  /// if a symbol originates from outside the current module.
  ///
  /// - Parameter symbol: The symbol to check for re-export status.
  /// - Returns: true if the symbol is re-exported and should be filtered out by default,
  ///   false if it's a legitimate module symbol.
  ///
  /// This function identifies symbols that come from external frameworks through
  /// @_exported import statements by examining their precise identifiers:
  /// - Objective-C symbols (c:objc*)
  /// - C symbols (c:*)
  /// - Swift bridging symbols for Objective-C types (s:...So...)
  private func isReexportedSymbol(_ symbol: SymbolGraph.Symbol) -> Bool {
    /// Check for external module patterns in the precise identifier
    let preciseID = symbol.identifier.precise

    /// Objective-C symbols (c:objc) are typically re-exported from Apple frameworks
    if preciseID.hasPrefix("c:objc") {
      return true
    }

    // C symbols (c:) - these are typically re-exported from C frameworks
    if preciseID.hasPrefix("c:") {
      return true
    }

    /// Swift bridging symbols for Objective-C types (s:...So...) that come from re-exports
    if preciseID.hasPrefix("s:"), preciseID.contains("So"), !preciseID.contains("Example") {
      return true
    }

    return false
  }

  /// Processes a single module and generates its documentation.
  ///
  /// This method handles the complete processing of a single module, including
  /// reading the main symbol graph file, loading any extension files, filtering
  /// symbols, organizing them into a hierarchy, and generating the final documentation.
  ///
  /// - Parameters:
  ///   - moduleName: The name of the module to process.
  ///   - fileName: The filename of the module's symbol graph file.
  /// - Throws: Errors if the symbol graph cannot be read or documentation generation fails.
  ///
  /// This method reads the main module symbol graph file and any extension files,
  /// filters symbols based on access level and re-export status, then delegates
  /// to generateModuleFile for the actual Markdown generation.
  private func processModule(moduleName: String, fileName: String) throws {
    print("Processing module: \(moduleName)")

    /// Read main module file
    let fileURL = symbolGraphsDir.appendingPathComponent(fileName)
    let data = try Data(contentsOf: fileURL)
    let graph = try JSONDecoder().decode(SymbolGraph.self, from: data)

    /// Also read extension files (e.g., ModuleName@Swift.symbols.json)
    var allSymbols = graph.symbols
    var allRelationships = graph.relationships ?? []
    let fm = FileManager.default
    if let files = try? fm.contentsOfDirectory(atPath: symbolGraphsDir.path) {
      let extensionFiles = files.filter { $0.hasPrefix("\(moduleName)@") && $0.hasSuffix(".symbols.json") }
      for extFile in extensionFiles {
        let extURL = symbolGraphsDir.appendingPathComponent(extFile)
        if let extData = try? Data(contentsOf: extURL),
           let extGraph = try? JSONDecoder().decode(SymbolGraph.self, from: extData)
        {
          allSymbols.append(contentsOf: extGraph.symbols)
          if let relationships = extGraph.relationships {
            allRelationships.append(contentsOf: relationships)
          }
        }
      }
    }

    /// Filter to public API symbols (public and open) and exclude synthesized ones
    /// Also filter out re-exported symbols unless explicitly included
    let publicSymbols = allSymbols.filter {
      ($0.accessLevel == "public" || $0.accessLevel == "open") &&
        !$0.identifier.precise.contains("::SYNTHESIZED::") &&
        (includeReexported || !isReexportedSymbol($0))
    }

    /// Group symbols by type and nesting
    var topLevelSymbols: [SymbolGraph.Symbol] = []
    var allSymbolsByPath: [String: SymbolGraph.Symbol] = [:] // path key -> symbol
    var extensionGroups: [String: [SymbolGraph.Symbol]] = [:] // extended type -> methods

    /// Build a map of all symbols by their path for easy lookup
    for symbol in publicSymbols {
      let pathKey = symbol.pathComponents.joined(separator: ".")
      allSymbolsByPath[pathKey] = symbol
    }

    /// Identify top-level symbols and extensions
    for symbol in publicSymbols {
      if symbol.pathComponents.count == 1 {
        /// Filter out re-exported symbols from top-level symbols as well
        if includeReexported || !isReexportedSymbol(symbol) {
          topLevelSymbols.append(symbol)
        }
      }
      else if symbol.pathComponents.count > 1 {
        let parent = symbol.pathComponents[0]

        /// Check if parent is one of our defined types
        let hasParentType = publicSymbols.contains { $0.pathComponents.count == 1 && $0.names.title == parent }

        if !hasParentType {
          /// This is an extension to an external type - only include direct children
          /// Also filter out re-exported symbols unless explicitly included
          if symbol.pathComponents.count == 2, includeReexported || !isReexportedSymbol(symbol) {
            if extensionGroups[parent] == nil {
              extensionGroups[parent] = []
            }
            extensionGroups[parent]?.append(symbol)
          }
        }
      }
    }

    /// Filter out empty extension groups
    extensionGroups = extensionGroups.filter { !$0.value.isEmpty }

    /// Skip modules with no symbols or extensions
    if topLevelSymbols.isEmpty, extensionGroups.isEmpty {
      print("  Skipping (no public symbols)")
      return
    }

    /// Generate single module file
    try generateModuleFile(
      moduleName: moduleName,
      symbols: topLevelSymbols,
      allSymbolsByPath: allSymbolsByPath,
      extensionGroups: extensionGroups,
      relationships: allRelationships
    )
  }

  /// Extracts a readable type name from a precise symbol identifier.
  ///
  /// This method attempts to demangle Swift symbol identifiers and map them to
  /// human-readable type names. It handles Objective-C symbols, standard library types,
  /// and uses swift-demangle for complex Swift symbols.
  ///
  /// - Parameter preciseIdentifier: The precise identifier from a symbol graph.
  /// - Returns: A readable type name if extraction succeeds, nil otherwise.
  private func extractTypeName(from preciseIdentifier: String) -> String? {
    // Handle Objective-C symbols: c:objc(cs)ClassName or c:objc(pl)ProtocolName
    if preciseIdentifier.hasPrefix("c:objc(cs)") || preciseIdentifier.hasPrefix("c:objc(pl)") {
      let parts = preciseIdentifier.components(separatedBy: ")")
      return parts.last
    }

    // Handle common Swift standard library types
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

    // For Swift symbols, use swift-demangle to get the proper name
    if preciseIdentifier.hasPrefix("s:") {
      // Convert to mangled format that swift-demangle expects (replace "s:" with "$s")
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
          // Output format: "$sMANGLED ---> Module.TypeName"
          if let arrowRange = demangled.range(of: " ---> ") {
            let fullName = String(demangled[arrowRange.upperBound...])
            // Extract just the type name (last component after last dot)
            if let lastDot = fullName.lastIndex(of: ".") {
              return String(fullName[fullName.index(after: lastDot)...])
            }
            return fullName
          }
        }
      }
      catch {
        // Fall through to return nil
      }
    }

    return nil
  }

  /// Extracts inheritance and conformance information for a symbol.
  ///
  /// This method analyzes the relationships for a symbol to find all parent classes
  /// it inherits from and protocols it conforms to. It filters out common, noisy
  /// conformances to keep the documentation focused on meaningful relationships.
  ///
  /// - Parameters:
  ///   - symbol: The symbol to analyze for inheritance/conformance.
  ///   - relationships: Array of relationships to search through.
  /// - Returns: Array of type names that the symbol inherits from or conforms to.
  private func getInheritanceConformance(for symbol: SymbolGraph.Symbol,
                                         relationships: [SymbolGraph.Relationship]) -> [String]
  {
    let sourceID = symbol.identifier.precise
    var types: [String] = []

    // Find all inheritsFrom and conformsTo relationships
    let relevantRelationships = relationships.filter {
      $0.source == sourceID && ($0.kind == "inheritsFrom" || $0.kind == "conformsTo")
    }

    for relationship in relevantRelationships {
      if let typeName = extractTypeName(from: relationship.target) {
        // Skip compiler-synthesized or inherited conformances that clutter the output
        let skipTypes = [
          "CVarArg",
          "Hashable",
          "Equatable",
          "Copyable",
          "CustomStringConvertible",
          "CustomDebugStringConvertible",
        ]
        if !skipTypes.contains(typeName) {
          types.append(typeName)
        }
      }
    }

    // Deduplicate while preserving order (inheritance first, then conformances)
    var seen = Set<String>()
    return types.filter { seen.insert($0).inserted }
  }

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
  private func findMainSymbol(symbols: [SymbolGraph.Symbol],
                              relationships: [SymbolGraph.Relationship],
                              moduleName: String) -> SymbolGraph.Symbol?
  {
    // Build a map of symbol IDs to symbols for quick lookup
    let symbolsByID = Dictionary(uniqueKeysWithValues: symbols.map { ($0.identifier.precise, $0) })

    // First priority: Find inheritance hierarchy - look for base classes/structs that others inherit from
    var inheritanceCounts: [String: Int] = [:]
    for relationship in relationships {
      if relationship.kind == "inheritsFrom" {
        let targetID = relationship.target
        // Check if the target is one of our symbols
        if symbolsByID[targetID] != nil {
          inheritanceCounts[targetID, default: 0] += 1
        }
      }
    }

    // Find the symbol with the most inheritors
    if let mostInheritedID = inheritanceCounts.max(by: { $0.value < $1.value })?.key,
       let mostInheritedSymbol = symbolsByID[mostInheritedID]
    {
      return mostInheritedSymbol
    }

    // Second priority: Look for symbol with name matching the module name
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
  private func buildDependencyGraph(symbols: [SymbolGraph.Symbol],
                                    relationships: [SymbolGraph.Relationship]) -> [String: Set<String>]
  {
    // Build a map of symbol IDs to their dependencies
    var dependencies: [String: Set<String>] = [:]
    let symbolsByID = Dictionary(uniqueKeysWithValues: symbols.map { ($0.identifier.precise, $0) })

    // Initialize empty dependencies for all symbols
    for symbol in symbols {
      dependencies[symbol.identifier.precise] = Set<String>()
    }

    // Analyze relationships to build dependencies
    for relationship in relationships {
      let sourceID = relationship.source
      let targetID = relationship.target

      // If both source and target are in our symbols, source depends on target
      if symbolsByID[sourceID] != nil,
         symbolsByID[targetID] != nil
      {
        dependencies[sourceID, default: Set<String>()].insert(targetID)
      }
    }

    return dependencies
  }

  /// Performs topological sort on symbols based on their dependencies.
  ///
  /// This method sorts symbols so that dependencies appear before the symbols
  /// that depend on them. This ensures proper documentation order where base
  /// classes and protocols are documented before their subclasses/conformers.
  ///
  /// - Parameters:
  ///   - symbols: Array of symbols to sort.
  ///   - dependencies: Dependency graph mapping symbol IDs to their dependencies.
  /// - Returns: Array of symbols sorted in dependency order.
  private func topologicalSort(symbols: [SymbolGraph.Symbol],
                               dependencies: [String: Set<String>]) -> [SymbolGraph.Symbol]
  {
    var remainingSymbols = symbols
    var processedIDs = Set<String>()
    var sortedSymbols: [SymbolGraph.Symbol] = []

    // Iteratively find symbols with no unprocessed dependencies
    while !remainingSymbols.isEmpty {
      var foundSymbol = false

      for (index, symbol) in remainingSymbols.enumerated() {
        let symbolID = symbol.identifier.precise
        let symbolDeps = dependencies[symbolID] ?? Set<String>()

        // Check if all dependencies have been processed
        if symbolDeps.isSubset(of: processedIDs) {
          sortedSymbols.append(symbol)
          processedIDs.insert(symbolID)
          remainingSymbols.remove(at: index)
          foundSymbol = true
          break
        }
      }

      // If we couldn't find a symbol with no dependencies, we have a cycle
      if !foundSymbol {
        // Add remaining symbols in their original order to break the cycle
        sortedSymbols.append(contentsOf: remainingSymbols)
        break
      }
    }

    return sortedSymbols
  }

  /// Determines the hierarchy rank for a symbol kind identifier.
  ///
  /// This method assigns a numeric rank to different symbol types to establish
  /// a documentation hierarchy. Lower ranks appear first in the documentation.
  /// The hierarchy is: Classes → Structs → Enums → Protocols → Extensions → Macros → Functions.
  ///
  /// - Parameter kindIdentifier: The kind identifier from a symbol graph.
  /// - Returns: Integer rank where lower numbers indicate higher priority in documentation.
  private func getTypeHierarchyRank(_ kindIdentifier: String) -> Int {
    // Define hierarchy: Classes (1) → Structs (2) → Enums (3) → Protocols (4) → Extensions (5) → Macros (6) → Functions
    // (7)
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
  private func sortSymbolsByHierarchy(symbols: [SymbolGraph.Symbol],
                                      dependencies: [String: Set<String>]) -> [SymbolGraph.Symbol]
  {
    // First, sort by dependencies using topological sort
    let dependencySorted = topologicalSort(symbols: symbols, dependencies: dependencies)

    // Then, group by type hierarchy while preserving dependency order where possible
    let grouped = Dictionary(grouping: dependencySorted) { symbol in
      getTypeHierarchyRank(symbol.kind.identifier)
    }

    // Sort groups by hierarchy rank and flatten
    let sortedRanks = grouped.keys.sorted()
    return sortedRanks.flatMap { grouped[$0]?.sorted(by: { $0.names.title < $1.names.title }) ?? [] }
  }

  private func generateModuleFile(moduleName: String, symbols: [SymbolGraph.Symbol],
                                  allSymbolsByPath: [String: SymbolGraph.Symbol],
                                  extensionGroups: [String: [SymbolGraph.Symbol]],
                                  relationships: [SymbolGraph.Relationship]) throws
  {
    var markdown = "## Module `\(moduleName)`\n\n"

    // Check for module README.md and include it if found
    if let modulePath = targetPaths[moduleName] {
      let readmePath = URL(fileURLWithPath: modulePath).appendingPathComponent("README.md")
      if FileManager.default.fileExists(atPath: readmePath.path) {
        do {
          let readmeContent = try String(contentsOf: readmePath, encoding: .utf8)
          // Remove the title if it matches the module name (avoid duplication)
          var processedContent = readmeContent
          if let firstLine = readmeContent.split(separator: "\n", maxSplits: 1).first,
             firstLine.trimmingCharacters(in: .whitespaces) == "# \(moduleName)"
          {
            // Skip the first line and any blank lines after it
            let lines = readmeContent.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count > 1 {
              processedContent = lines.dropFirst().joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            }
          }

          // Adjust heading levels so the highest heading becomes H3
          processedContent = adjustHeadingLevels(in: processedContent)

          markdown += processedContent.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
        }
        catch {
          print("  Warning: Found README.md but couldn't read it: \(error.localizedDescription)")
        }
      }
    }

    // Build dependency graph for hierarchy-based sorting
    let dependencies = buildDependencyGraph(symbols: symbols, relationships: relationships)

    // Find the main symbol (if any) that should appear first
    let mainSymbol = findMainSymbol(symbols: symbols, relationships: relationships, moduleName: moduleName)

    // Sort symbols by hierarchy (dependencies first, then by type hierarchy)
    let hierarchySortedSymbols = sortSymbolsByHierarchy(symbols: symbols, dependencies: dependencies)

    // Separate main symbol from the rest if found
    var orderedSymbols: [SymbolGraph.Symbol] = []
    var remainingSymbols: [SymbolGraph.Symbol] = []

    if let main = mainSymbol {
      orderedSymbols.append(main)
      remainingSymbols = hierarchySortedSymbols.filter { $0.identifier.precise != main.identifier.precise }
    }
    else {
      remainingSymbols = hierarchySortedSymbols
    }

    // Add public interface heading before first code block
    var hasAddedHeading = false
    func writeInterfaceBlock(_ symbols: [SymbolGraph.Symbol]) {
      if symbols.isEmpty {
        return
      }

      if !hasAddedHeading {
        markdown += "### Public interface\n\n"
        hasAddedHeading = true
      }

      markdown += "```swift\n"
      for (index, symbol) in symbols.enumerated() {
        if index > 0 {
          markdown += "\n"
        }
        markdown += generateInterfaceDeclaration(
          symbol: symbol,
          allSymbolsByPath: allSymbolsByPath,
          relationships: relationships,
          indent: ""
        )
      }
      markdown += "```\n\n"
    }

    // Write main symbol first if found
    if !orderedSymbols.isEmpty {
      writeInterfaceBlock(orderedSymbols)
    }

    // Write remaining symbols
    writeInterfaceBlock(remainingSymbols)

    // Write extension groups (extensions to external types) with hierarchy-based ordering
    if !extensionGroups.isEmpty {
      if !hasAddedHeading {
        markdown += "### Public interface\n\n"
        hasAddedHeading = true
      }

      markdown += "```swift\n"

      // Sort extension groups using the same hierarchy logic
      var sortedExtensionGroups: [(String, [SymbolGraph.Symbol])] = []

      for (extendedType, methods) in extensionGroups {
        // Build dependencies for extension methods
        let extDependencies = buildDependencyGraph(symbols: methods, relationships: relationships)
        // Sort methods by hierarchy
        let sortedMethods = sortSymbolsByHierarchy(symbols: methods, dependencies: extDependencies)
        sortedExtensionGroups.append((extendedType, sortedMethods))
      }

      // Sort extension groups by extended type name
      sortedExtensionGroups.sort { $0.0 < $1.0 }

      for (index, (extendedType, methods)) in sortedExtensionGroups.enumerated() {
        // Only generate extension if it has members after filtering
        if !methods.isEmpty {
          if index > 0 {
            markdown += "\n"
          }
          markdown += generateExtensionInterface(extendedType: extendedType, methods: methods)
        }
      }
      markdown += "```\n\n"
    }

    // Add timestamp at the bottom
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    let timestamp = dateFormatter.string(from: Date())
    markdown += "<!-- Generated by interfazzle.swift on \(timestamp) -->\n"

    let fileURL = outputDir.appendingPathComponent("\(moduleName).md")
    try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
    print("  Generated \(moduleName).md")
  }

  private func formatDeclaration(fragments: [SymbolGraph.Symbol.DeclarationFragment], addPublic: Bool) -> String {
    // Filter out unwanted keywords/attributes
    let filtered = fragments.filter {
      !["nonisolated", "@MainActor"].contains($0.spelling.trimmingCharacters(in: .whitespaces))
    }

    var declaration = filtered.map(\.spelling).joined()

    // Add public modifier if needed and not already present
    if addPublic, !declaration.hasPrefix("public") {
      declaration = "public " + declaration
    }

    return declaration
  }

  private func formatDocComment(_ docComment: SymbolGraph.Symbol.DocComment?, indent: String = "") -> String {
    guard let docComment else {
      return ""
    }

    var result = ""
    var inParametersSection = false

    for line in docComment.lines {
      let text = line.text
      let trimmed = text.trimmingCharacters(in: .whitespaces)

      // Skip parameters section as we'll show them inline in declarations
      if trimmed.hasPrefix("- Parameters:") || trimmed.hasPrefix("-Parameters:") {
        inParametersSection = true
        continue
      }

      if inParametersSection {
        if trimmed.hasPrefix("-"), !trimmed.contains(":") {
          // New section, end parameters
          inParametersSection = false
        }
        else {
          // Skip parameter details
          continue
        }
      }

      if !inParametersSection {
        result += "\(indent)/// \(text)\n"
      }
    }

    return result
  }

  private func generateInterfaceDeclaration(symbol: SymbolGraph.Symbol,
                                            allSymbolsByPath: [String: SymbolGraph.Symbol],
                                            relationships: [SymbolGraph.Relationship],
                                            indent: String) -> String
  {
    var result = ""

    // Add doc comment for the type
    result += formatDocComment(symbol.docComment, indent: indent)

    // Type declaration
    if let fragments = symbol.declarationFragments {
      var declaration = formatDeclaration(fragments: fragments, addPublic: true)

      // Add inheritance/conformance for classes, structs, and enums only
      // Protocols already include inheritance in their declaration fragments
      let needsInheritance = ["swift.class", "swift.struct", "swift.enum"].contains(symbol.kind.identifier)
      if needsInheritance {
        let inherited = getInheritanceConformance(for: symbol, relationships: relationships)
        if !inherited.isEmpty {
          declaration += ": " + inherited.joined(separator: ", ")
        }
      }

      // For standalone functions/macros, just add the declaration
      if symbol.kind.identifier == "swift.func" || symbol.kind.identifier == "swift.macro" {
        result += "\(indent)\(declaration)\n"
        return result
      }

      result += "\(indent)\(declaration) {\n"
    }

    // Get direct children only (path length = current path length + 1)
    let currentPathLength = symbol.pathComponents.count
    let directChildren = allSymbolsByPath.values.filter { child in
      child.pathComponents.count == currentPathLength + 1 &&
        child.pathComponents.prefix(currentPathLength) == symbol.pathComponents[...]
    }

    // Separate nested types from members
    let nestedTypes = directChildren.filter {
      ["swift.struct", "swift.class", "swift.enum", "swift.protocol"].contains($0.kind.identifier)
    }
    let members = directChildren.filter { member in
      !nestedTypes.contains { $0.pathComponents == member.pathComponents }
    }

    // Group members by kind
    let typeProperties = members.filter { $0.kind.identifier.contains("type.property") }
    let typeMethods = members.filter { $0.kind.identifier.contains("type.method") }
    let properties = members.filter {
      $0.kind.identifier.contains("property") && !$0.kind.identifier.contains("type.property")
    }
    let methods = members.filter {
      ($0.kind.identifier.contains("method") || $0.kind.identifier.contains("init")) &&
        !$0.kind.identifier.contains("type.method")
    }
    let enumCases = members.filter { $0.kind.identifier == "swift.enum.case" }

    let memberIndent = indent + "  "
    var hasContent = false

    // Render nested types first
    for nestedType in nestedTypes.sorted(by: { $0.names.title < $1.names.title }) {
      if hasContent {
        result += "\n"
      }
      result += generateInterfaceDeclaration(
        symbol: nestedType,
        allSymbolsByPath: allSymbolsByPath,
        relationships: relationships,
        indent: memberIndent
      )
      hasContent = true
    }

    // Render type properties
    for prop in typeProperties.sorted(by: { $0.names.title < $1.names.title }) {
      if hasContent {
        result += "\n"
      }
      result += formatDocComment(prop.docComment, indent: memberIndent)
      if let fragments = prop.declarationFragments {
        let declaration = formatDeclaration(fragments: fragments, addPublic: true)
        result += "\(memberIndent)\(declaration)\n"
      }
      hasContent = true
    }

    // Render instance properties
    for prop in properties.sorted(by: { $0.names.title < $1.names.title }) {
      if hasContent {
        result += "\n"
      }
      result += formatDocComment(prop.docComment, indent: memberIndent)
      if let fragments = prop.declarationFragments {
        let declaration = formatDeclaration(fragments: fragments, addPublic: true)
        result += "\(memberIndent)\(declaration)\n"
      }
      hasContent = true
    }

    // Render enum cases
    for enumCase in enumCases.sorted(by: { $0.names.title < $1.names.title }) {
      if hasContent {
        result += "\n"
      }
      result += formatDocComment(enumCase.docComment, indent: memberIndent)
      if let fragments = enumCase.declarationFragments {
        let declaration = formatDeclaration(fragments: fragments, addPublic: true)
        result += "\(memberIndent)\(declaration)\n"
      }
      hasContent = true
    }

    // Render type methods
    for method in typeMethods.sorted(by: { $0.names.title < $1.names.title }) {
      if hasContent {
        result += "\n"
      }
      result += formatDocComment(method.docComment, indent: memberIndent)
      if let fragments = method.declarationFragments {
        let declaration = formatDeclaration(fragments: fragments, addPublic: true)
        result += "\(memberIndent)\(declaration)\n"
      }
      hasContent = true
    }

    // Render instance methods
    for method in methods.sorted(by: { $0.names.title < $1.names.title }) {
      if hasContent {
        result += "\n"
      }
      result += formatDocComment(method.docComment, indent: memberIndent)
      if let fragments = method.declarationFragments {
        let declaration = formatDeclaration(fragments: fragments, addPublic: true)
        result += "\(memberIndent)\(declaration)\n"
      }
      hasContent = true
    }

    result += "\(indent)}\n"
    return result
  }

  private func generateExtensionInterface(extendedType: String, methods: [SymbolGraph.Symbol]) -> String {
    var result = ""

    result += "extension \(extendedType) {\n"

    // Group by kind
    let properties = methods.filter { $0.kind.identifier.contains("property") }
    let functions = methods.filter { $0.kind.identifier.contains("method") || $0.kind.identifier.contains("func") }

    var allMembers = properties + functions
    allMembers.sort { $0.names.title < $1.names.title }

    for (index, member) in allMembers.enumerated() {
      if index > 0 {
        result += "\n"
      }
      result += formatDocComment(member.docComment, indent: "  ")
      if let fragments = member.declarationFragments {
        let declaration = formatDeclaration(fragments: fragments, addPublic: true)
        result += "  \(declaration)\n"
      }
    }

    result += "}\n"
    return result
  }
}

// MARK: - Helper Functions

/// Adjusts heading levels in markdown content to fit within documentation hierarchy.
///
/// This function ensures that markdown headings are properly nested within the
/// generated documentation by shifting all heading levels so the highest level
/// becomes H3 (to fit under the main module H2 heading).
///
/// - Parameter markdown: The markdown content to adjust.
/// - Returns: Markdown with adjusted heading levels.
func adjustHeadingLevels(in markdown: String) -> String {
  let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

  // Find the minimum heading level (highest priority heading)
  var minLevel: Int?
  for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("#") {
      // Count the number of # characters
      let hashCount = trimmed.prefix(while: { $0 == "#" }).count
      if hashCount > 0, hashCount <= 6 {
        // Make sure there's a space after the hashes (valid markdown heading)
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

  // If no headings found, return original
  guard let minLevel else {
    return markdown
  }

  // Calculate shift needed to make minLevel become level 3 (H3)
  let targetLevel = 3
  let shift = targetLevel - minLevel

  // If no shift needed, return original
  if shift == 0 {
    return markdown
  }

  // Apply shift to all headings
  var result: [String] = []
  for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("#") {
      let hashCount = trimmed.prefix(while: { $0 == "#" }).count
      if hashCount > 0, hashCount <= 6 {
        // Check for valid heading (space after hashes)
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

/// Loads package description and extracts target path information.
///
/// This function runs `swift package describe --type json` to get information
/// about the package targets and their file system locations. The returned
/// mapping is used to locate README.md files within each target directory.
///
/// - Returns: Dictionary mapping target names to their relative file system paths.
/// - Throws: NSError if the swift package describe command fails.
func loadPackageDescription() throws -> [String: String] {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
  process.arguments = ["package", "describe", "--type", "json"]

  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = Pipe()

  try process.run()
  process.waitUntilExit()

  guard process.terminationStatus == 0 else {
    throw NSError(
      domain: "DocumentationGenerator",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Failed to run 'swift package describe'"]
    )
  }

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let packageDesc = try JSONDecoder().decode(PackageDescription.self, from: data)

  // Build a dictionary of target name -> path
  var targetPaths: [String: String] = [:]
  for target in packageDesc.targets {
    targetPaths[target.name] = target.path
  }

  return targetPaths
}

// MARK: - Main Entry Point

/// Main entry point for the interfazzle documentation generator.
///
/// This function orchestrates the entire documentation generation process:
/// 1. Parses command line arguments
/// 2. Validates the Swift package environment
/// 3. Builds symbol graphs (unless --generate-only is specified)
/// 4. Generates Markdown documentation for the specified modules
///
/// The function handles various error conditions and provides appropriate
/// exit codes for different failure scenarios.
func main() {
  do {
    // Parse arguments
    guard let config = parseArguments() else {
      exit(1)
    }

    // Step 1: Validate Package.swift exists
    try validatePackageSwift()

    // Step 2: Load package description to get target paths
    print("📦 Loading package description...")
    let targetPaths = try loadPackageDescription()

    // Step 3: Build symbol graphs (unless --generate-only)
    if !config.generateOnly {
      let modules = try extractPublicModules()
      print("📦 Generating documentation for modules:")
      for module in modules {
        print("   - \(module)")
      }
      print()

      do {
        try buildSymbolGraphs(symbolGraphsDir: config.symbolGraphsDir, verbose: config.verbose)
        print("✅ Symbol graphs generated\n")
      }
      catch let error as NSError {
        if config.beLenient {
          print("⚠️  Build failed, but continuing with existing symbol graphs (--be-lenient)")
          if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            print("   Build output:")
            print(reason)
          }
          print()
        }
        else {
          print("❌ \(error.localizedDescription)")
          if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            print("\n\(reason)")
          }
          exit(2)
        }
      }
    }
    else {
      print("⏭️  Skipping build (--generate-only)\n")
    }

    // Step 4: Generate documentation
    print("📝 Generating Markdown documentation...")

    // Determine which modules to document
    // If user specified modules, use those; otherwise default to public product modules
    let modulesToDocument: Set<String>
    if let userModules = config.modules {
      modulesToDocument = userModules
      print("   Filtering to modules: \(modulesToDocument.sorted().joined(separator: ", "))")
    }
    else {
      // Default behavior: only document public product modules (not dependencies)
      let publicModules = try extractPublicModules()
      modulesToDocument = Set(publicModules)
      print("   Filtering to public product modules: \(modulesToDocument.sorted().joined(separator: ", "))")
    }

    let symbolGraphsURL = URL(fileURLWithPath: config.symbolGraphsDir)
    let outputURL = URL(fileURLWithPath: config.outputDir)

    // Create output directory if needed
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let generator = DocumentationGenerator(
      symbolGraphsDir: symbolGraphsURL,
      outputDir: outputURL,
      targetPaths: targetPaths,
      includeReexported: config.includeReexported
    )

    try generator.generate(includeOnly: modulesToDocument)

    print("\n✅ Documentation generated in \(config.outputDir)")
  }
  catch let error as NSError where error.code == 1 {
    print(error.localizedDescription)
    exit(1)
  }
  catch let error as NSError where error.code == 2 {
    print("❌ \(error.localizedDescription)")
    exit(2)
  }
  catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(3)
  }
}

// Run main
main()
