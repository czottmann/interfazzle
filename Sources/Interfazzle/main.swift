#!/usr/bin/env swift

import Foundation
import SwiftCLI

/// Main entry point for the interfazzle CLI.
///
/// This file initializes the SwiftCLI framework and registers all available commands.
let cli = CLI(
  name: "interfazzle",
  version: "2.0.0",
  description: "Generate API documentation from Swift symbol graphs"
)

/// Register commands
cli.commands = [
  GenerateCommand(),
  BuildCommand(),
  ValidateCommand(),
]

/// Set default command to generate
cli.defaultCommand = GenerateCommand()

/// Run the CLI
cli.go()
