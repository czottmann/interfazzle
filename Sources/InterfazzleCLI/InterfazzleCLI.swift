import Foundation
@preconcurrency import SwiftCLI

/// Main entry point for the interfazzle CLI.
///
/// This initializes the SwiftCLI framework and registers all available commands.
@main
struct InterfazzleCLI {
  static func main() {
    /// Print banner if no arguments or if --help is present
    if CommandLine.arguments.count == 1 || CommandLine.arguments.contains("--help") {
      printBanner()
    }

    let cli = CLI(
      name: "interfazzle",
      version: packageVersion,
      description: "Generate API documentation for Swift packages from symbol graphs"
    )

    cli.commands = [
      GenerateCommand(),
      BuildCommand(),
      ValidateCommand(),
    ]

    cli.go()
  }

  /// Prints the interfazzle banner to stdout.
  static func printBanner() {
    print("""
    ░░░▀█▀░█▀█░▀█▀░█▀▀░█▀▄░█▀▀░█▀█░▀▀█░▀▀█░█░░░█▀▀░░░░
    ░░░░█░░█░█░░█░░█▀▀░█▀▄░█▀▀░█▀█░▄▀░░▄▀░░█░░░█▀▀░░░░
    ░░░▀▀▀░▀░▀░░▀░░▀▀▀░▀░▀░▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░░░░
    """)
  }
}
