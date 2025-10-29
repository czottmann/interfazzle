import Foundation
import Interfazzle
import SwiftCLI

/// Command to validate the package setup.
///
/// This command verifies that Package.swift exists in the current directory
/// and that the package is properly configured.
class ValidateCommand: Command {
  // MARK: - Properties

  let name = "validate"
  let shortDescription = "Validate Package.swift exists and is readable"

  // MARK: - Functions

  func execute() throws {
    let validator = PackageValidator()
    try validator.validate()
    print("✅ Package.swift found and validated")
  }
}
