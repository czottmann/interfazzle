import Foundation

/// Configuration settings for the interfazzle documentation generator.
///
/// This struct encapsulates all command-line options and settings that control
/// how symbol graphs are built and documentation is generated.
public struct Config {
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
  public static let `default` = Config(
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
  public let symbolGraphsDir: String

  /// Directory path where generated Markdown documentation files will be written.
  ///
  /// Each module will generate a separate .md file in this directory.
  public let outputDir: String

  /// Optional set of module names to include in documentation generation.
  ///
  /// When nil, all public product modules will be documented. When specified,
  /// only the modules in this set will be processed.
  public let modules: Set<String>?

  /// Whether to skip the build phase and use existing symbol graphs.
  ///
  /// When true, the script will not run `swift build` and will instead
  /// attempt to generate documentation from symbol graphs that already exist
  /// in the symbolGraphsDir.
  public let generateOnly: Bool

  /// Whether to display full build output from Swift compilation.
  ///
  /// When false (default), build output is captured and only shown on error.
  /// When true, all build output is displayed in real-time.
  public let verbose: Bool

  /// Whether to continue documentation generation despite build failures.
  ///
  /// When true, if the Swift build fails, the script will attempt to generate
  /// documentation from any existing symbol graphs instead of exiting with an error.
  public let beLenient: Bool

  /// Whether to include symbols that are re-exported from external modules.
  ///
  /// When false (default), symbols from external frameworks (via @_exported import)
  /// are filtered out to focus on the package's own API. When true, these symbols
  /// are included in the generated documentation.
  public let includeReexported: Bool

  // MARK: - Lifecycle

  /// Initializes a new Config instance.
  ///
  /// - Parameters:
  ///   - symbolGraphsDir: Directory for symbol graphs
  ///   - outputDir: Directory for generated documentation
  ///   - modules: Optional set of modules to document
  ///   - generateOnly: Whether to skip the build phase
  ///   - verbose: Whether to show full build output
  ///   - beLenient: Whether to continue on build failure
  ///   - includeReexported: Whether to include re-exported symbols
  public init(symbolGraphsDir: String,
              outputDir: String,
              modules: Set<String>?,
              generateOnly: Bool,
              verbose: Bool,
              beLenient: Bool,
              includeReexported: Bool)
  {
    self.symbolGraphsDir = symbolGraphsDir
    self.outputDir = outputDir
    self.modules = modules
    self.generateOnly = generateOnly
    self.verbose = verbose
    self.beLenient = beLenient
    self.includeReexported = includeReexported
  }
}
