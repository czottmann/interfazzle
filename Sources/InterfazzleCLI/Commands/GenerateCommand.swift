import Foundation
import Interfazzle
import SwiftCLI

/// Main command to generate documentation from symbol graphs.
///
/// This command orchestrates the complete documentation generation workflow:
/// building symbol graphs, extracting module information, and generating Markdown docs.
class GenerateCommand: Command {
  // MARK: - Properties

  let name = "generate"
  let shortDescription = "Generate API documentation from Swift symbol graphs"

  @Flag("--generate-only", description: "Skip build phase, use existing symbol graphs")
  var generateOnly: Bool

  @Flag("-v", "--verbose", description: "Show full swift build output")
  var verbose: Bool

  @Flag("--be-lenient", description: "On build failure, try generating from existing graphs")
  var beLenient: Bool

  @Flag("--include-reexported", description: "Include re-exported symbols in documentation")
  var includeReexported: Bool

  @Key("--symbol-graphs-dir", description: "Directory for symbol graphs (default: .build/symbol-graphs)")
  var symbolGraphsDir: String?

  @Key("--output-dir", description: "Output directory for documentation (default: docs)")
  var outputDir: String?

  @Key("--modules", description: "Comma-separated list of modules to document (default: all public products)")
  var modules: String?

  // MARK: - Functions

  func execute() throws {
    /// Parse modules if provided (comma-separated)
    let moduleSet: Set<String>? = modules.map { modulesString in
      Set(modulesString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
    }

    let config = Config(
      symbolGraphsDir: symbolGraphsDir ?? Config.default.symbolGraphsDir,
      outputDir: outputDir ?? Config.default.outputDir,
      modules: moduleSet,
      generateOnly: generateOnly,
      verbose: verbose,
      beLenient: beLenient,
      includeReexported: includeReexported
    )

    /// Step 1: Validate Package.swift exists
    let validator = PackageValidator()
    do {
      try validator.validate()
    }
    catch {
      print(error.localizedDescription)
      throw CLI.Error(message: "", exitStatus: 1)
    }

    /// Step 2: Load package information using centralized provider
    print("📦 Loading package description...")
    let packageInfoProvider = PackageInfoProvider()
    let packageLoader = PackageInfoLoader(packageInfoProvider: packageInfoProvider)
    let moduleExtractor = ModuleExtractor(packageInfoProvider: packageInfoProvider)

    let targetPaths: [String: String]
    do {
      targetPaths = try packageLoader.loadPackageDescription()
    }
    catch {
      print("❌ Error: \(error.localizedDescription)")
      throw CLI.Error(message: "", exitStatus: 1)
    }

    /// Step 3: Build symbol graphs (unless --generate-only)
    if !config.generateOnly {
      let modules: [String]
      do {
        modules = try moduleExtractor.extractPublicModules()
      }
      catch {
        print("❌ Error: \(error.localizedDescription)")
        throw CLI.Error(message: "", exitStatus: 1)
      }

      print("📦 Generating documentation for modules:")
      for module in modules {
        print("   - \(module)")
      }
      print()

      let builder = SymbolGraphBuilder()
      do {
        try builder.build(symbolGraphsDir: config.symbolGraphsDir, verbose: config.verbose)
        print("✅ Symbol graphs generated\n")
      }
      catch {
        if config.beLenient {
          print("⚠️  Build failed, but continuing with existing symbol graphs (--be-lenient)")
          print("   Build error: \(error.localizedDescription)")
          print()
        }
        else {
          print("❌ Build failed")
          print(error.localizedDescription)
          throw CLI.Error(message: "", exitStatus: 2)
        }
      }
    }
    else {
      print("⏭️  Skipping build (--generate-only)\n")
    }

    /// Step 4: Generate documentation with concurrent file processing
    print("📝 Generating Markdown documentation...")

    /// Determine which modules to document
    let modulesToDocument: Set<String>
    if let userModules = config.modules {
      modulesToDocument = userModules
      print("   Filtering to modules: \(modulesToDocument.sorted().joined(separator: ", "))")
    }
    else {
      /// Default behavior: only document public product modules (not dependencies)
      /// Reuse the same moduleExtractor to benefit from cached data
      let publicModules: [String]
      do {
        publicModules = try moduleExtractor.extractPublicModules()
      }
      catch {
        print("❌ Error: \(error.localizedDescription)")
        throw CLI.Error(message: "", exitStatus: 1)
      }
      modulesToDocument = Set(publicModules)
      print("   Filtering to public product modules: \(modulesToDocument.sorted().joined(separator: ", "))")
    }

    let symbolGraphsURL = URL(fileURLWithPath: config.symbolGraphsDir)
    let outputURL = URL(fileURLWithPath: config.outputDir)

    /// Create output directory if needed
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let generator = DocumentationGenerator(
      symbolGraphsDir: symbolGraphsURL,
      outputDir: outputURL,
      targetPaths: targetPaths,
      includeReexported: config.includeReexported
    )

    do {
      try generator.generate(includeOnly: modulesToDocument)
      print("\n✅ Documentation generated in \(config.outputDir)")
    }
    catch {
      print("❌ Error generating documentation: \(error.localizedDescription)")
      throw CLI.Error(message: "", exitStatus: 3)
    }
  }
}
