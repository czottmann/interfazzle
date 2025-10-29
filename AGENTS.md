# AGENTS.md

This file provides guidance to LLM agents when working with code in this repository.

## Project Overview

Swift-interfazzle is a Swift package that generates Markdown documentation for Swift package public interfaces from symbol graphs. It's designed as a replacement for SourceDocs, avoiding crashes when packages include dependencies with pre-built binaries.

**Key characteristics:**

- Proper Swift package with library and executable targets
- Uses SwiftCLI framework for command-line interface
- Modular architecture with clear separation of concerns
- Comprehensive unit tests using Swift Testing framework
- Targeted at package maintainers and LLM-friendly documentation

## Package Structure

The package follows Swift Package Manager conventions:

```
swift-interfazzle/
├── Package.swift              # Package manifest
├── Sources/
│   ├── Interfazzle/          # Library module (public API)
│   │   ├── Models/           # Data structures (Config, SymbolGraph, PackageDescription)
│   │   ├── Core/             # Workflow components (validation, building, extraction)
│   │   └── Generation/       # Documentation generation (formatting, sorting, output)
│   └── InterfazzleCLI/       # Executable module
│       ├── InterfazzleCLI.swift  # @main entry point
│       └── Commands/         # CLI commands (Generate, Build, Validate)
├── Tests/
│   └── InterfazzleTests/     # Unit tests
└── interfazzle.legacy.swift  # Original monolithic script (reference only)
```

## Core Modules

### Interfazzle Library

The core library provides all documentation generation functionality:

**Models/** - Data structures

- `Config.swift` - Configuration with command-line options
- `SymbolGraph.swift` - Codable types for Swift compiler symbol graphs
- `PackageDescription.swift` - Package metadata from `swift package describe`

**Core/** - Workflow components

- `PackageValidator.swift` - Validates Package.swift existence
- `SymbolGraphBuilder.swift` - Orchestrates Swift compiler to generate symbol graphs
- `ModuleExtractor.swift` - Extracts public module names from Package.swift
- `PackageInfoLoader.swift` - Loads target path information for README integration

**Generation/** - Documentation generation

- `DocumentationGenerator.swift` - Main orchestrator for doc generation
- `SymbolSorter.swift` - Sorts symbols by dependency and type hierarchy
- `DeclarationFormatter.swift` - Formats Swift declaration fragments
- `MarkdownFormatter.swift` - Generates final Markdown output

### InterfazzleCLI Executable

Command-line interface using SwiftCLI framework:

- `InterfazzleCLI.swift` - Entry point with CLI initialization
- `GenerateCommand.swift` - Main workflow (build + generate docs)
- `BuildCommand.swift` - Build symbol graphs only
- `ValidateCommand.swift` - Validate Package.swift existence

## Common Development Commands

### Building and Running

```bash
# Build the package
swift build

# Run interfazzle
swift run interfazzle generate

# Run with flags
swift run interfazzle generate --verbose --be-lenient
swift run interfazzle generate --generate-only

# Show help
swift run interfazzle --help
swift run interfazzle generate --help

# Other commands
swift run interfazzle build
swift run interfazzle validate
```

### Installing Locally

```bash
# Build release version
swift build -c release

# Copy to PATH
cp .build/release/interfazzle /usr/local/bin/
```

### Testing

```bash
# Run all tests
swift test

# Build and run tests
swift test --parallel
```

### Development/Debugging Commands

```bash
# Manual symbol graph generation
swift build -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs

# Package analysis
swift package describe --type json

# Clean build artifacts
swift package clean
rm -rf .build
```

## CLI Commands

### generate

Generate complete documentation (build + convert):

```bash
interfazzle generate [options]
```

**Flags:**

- `--generate-only` - Skip build phase, use existing symbol graphs
- `-v, --verbose` - Show full build output
- `--be-lenient` - Continue with existing graphs if build fails
- `--include-reexported` - Include re-exported symbols from dependencies
- `--symbol-graphs-dir <dir>` - Symbol graph directory (default: `.build/symbol-graphs`)
- `--output-dir <dir>` - Output directory (default: `docs`)
- `--modules <list>` - Comma-separated module list (default: all public products)

### build

Build symbol graphs without generating documentation:

```bash
interfazzle build [options]
```

**Flags:**

- `-v, --verbose` - Show full build output
- `--symbol-graphs-dir <dir>` - Symbol graph directory (default: `.build/symbol-graphs`)

### validate

Verify Package.swift exists in current directory:

```bash
interfazzle validate
```

## Code Organization Patterns

**Swift 6 Compliance:**

- Uses `Sendable` conformance for concurrency safety
- `@preconcurrency` imports for SwiftCLI
- Modern `async`/`await` patterns where appropriate

**Error Handling:**

- Uses Swift Error protocol with LocalizedError
- Structured error types per module (BuildError, ValidationError, etc.)
- Exit codes: 0 (success), 1 (validation), 2 (build), 3 (generation)

**Documentation:**

- Triple-slash (`///`) doc comments on all public APIs
- Detailed parameter and return value documentation
- Examples in doc comments where helpful

**Testing:**

- Swift Testing framework with `@Suite` and `@Test` macros
- Tests organized in nested suites by component
- Focus on public API contracts

## Development Workflow

### Core Workflow

1. Validate Package.swift exists (`PackageValidator`)
2. Extract public modules using `swift package describe` (`ModuleExtractor`)
3. Load target paths for README integration (`PackageInfoLoader`)
4. Build symbol graphs using Swift compiler (`SymbolGraphBuilder`)
5. Generate Markdown documentation (`DocumentationGenerator`)

### Adding New Features

1. Add functionality to appropriate module (Models/Core/Generation)
2. Add tests in `Tests/InterfazzleTests/`
3. Update CLI commands if user-facing
4. Update README.md with new usage
5. Regenerate documentation: `swift run interfazzle generate`

### Code Style

- Follow Swift API Design Guidelines
- Use 2-space indentation (configured in project)
- Organize code with `// MARK:` comments
- Keep files focused and under 300 lines where possible
- Use descriptive names over brevity

## Important Constraints

- Must be run from Swift package root (where Package.swift exists)
- macOS only (uses `Process` to run shell commands)
- Requires Swift 6.0+
- Uses system Swift compiler for symbol graph generation
- Only documents public API symbols (`public` and `open` access levels)
- Automatically filters to public product modules (excludes dependencies)

## Documentation Output Format

Generates interface-style Markdown similar to Xcode's generated interfaces:

- H2 heading with module name (e.g., `## Module \`Interfazzle\``)
- Optional README content with adjusted heading levels (from module source directory)
- H3 heading: "Public interface"
- Swift code blocks with complete interface declarations
- Doc comments as triple-slash (`///`) syntax above declarations
- Symbols grouped by type (protocols → structs → classes → enums → extensions → macros → functions)
- Nested types rendered within parent declarations
- Generation timestamp footer

## Dependencies

- **SwiftCLI** (6.0.3+) - Command-line interface framework
  - Used only by InterfazzleCLI executable
  - Not a dependency of Interfazzle library

## Legacy Script

The original monolithic `interfazzle.swift` script is preserved as `interfazzle.legacy.swift` for reference. It should not be used or modified. All development should use the modular Swift package structure.
