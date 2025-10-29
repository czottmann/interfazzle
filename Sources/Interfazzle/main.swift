import Foundation
@preconcurrency import SwiftCLI

/// Main entry point for the interfazzle CLI.
///
/// This initializes the SwiftCLI framework and registers all available commands.
@main
struct Interfazzle {
  static func main() {
    let cli = CLI(
      name: "interfazzle",
      version: "2.0.0",
      description: "Generate API documentation from Swift symbol graphs"
    )

    cli.commands = [
      GenerateCommand(),
      BuildCommand(),
      ValidateCommand(),
    ]

    cli.go()
  }
}
