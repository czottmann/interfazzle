import Foundation
import Interfazzle
import SwiftCLI

/// Command to build symbol graphs only.
///
/// This command builds the Swift package with symbol graph generation enabled,
/// without generating documentation. Useful for preparing symbol graphs for later
/// documentation generation.
class BuildCommand: Command {
  // MARK: - Properties

  let name = "build"
  let shortDescription = "Build symbol graphs without generating documentation"

  @Flag("-v", "--verbose", description: "Show full swift build output")
  var verbose: Bool

  @Param var symbolGraphsDir: String?

  // MARK: - Functions

  func execute() throws {
    let config = Config(
      symbolGraphsDir: symbolGraphsDir ?? Config.default.symbolGraphsDir,
      outputDir: Config.default.outputDir,
      modules: nil,
      generateOnly: false,
      verbose: verbose,
      beLenient: false,
      includeReexported: false
    )

    /// Validate package
    let validator = PackageValidator()
    try validator.validate()

    /// Build symbol graphs
    let builder = SymbolGraphBuilder()
    try builder.build(symbolGraphsDir: config.symbolGraphsDir, verbose: config.verbose)

    print("✅ Symbol graphs generated in \(config.symbolGraphsDir)")
  }
}
