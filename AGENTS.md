# AGENTS.md

This file provides guidance to LLM agents when working with code in this repository.

## Project Overview

Swift-interfizzle is a self-contained Swift script tool that generates Markdown documentation for Swift package public interfaces from symbol graphs. It's designed as a replacement for SourceDocs, avoiding crashes when packages include dependencies with pre-built binaries.

**Key characteristics:**

- Single-file architecture (1,132-line monolithic script)
- Self-contained executable Swift script with shebang
- No external dependencies beyond Foundation
- Targeted at package maintainers

## Core Architecture

The script follows a clear modular structure within `interfizzle.swift`:

```
Config (lines 5-27)           - Configuration management
CLI Parsing (lines 29-140)    - Command-line argument handling
Orchestration (lines 141-258) - Core workflow management
Data Models (lines 265-360)   - JSON parsing for symbol graphs
DocumentationGenerator (lines 363-1000) - Main generation logic
Main Function (lines 1035-1132) - Entry point and error handling
```

**Key classes:**

- `Config`: Configuration with default values
- `DocumentationGenerator`: Core document generation logic
- `PackageDescription`: Swift package metadata parsing
- `SymbolGraph`: JSON model for compiler symbol graphs

## Common Development Commands

### Running the Tool

```bash
# Primary usage from Swift package root
./interfizzle.swift

# With flags
./interfizzle.swift --verbose --be-lenient
./interfizzle.swift --generate-only

# Show help
./interfizzle.swift --help
```

### Development/Debugging Commands

```bash
# Manual symbol graph generation (for debugging)
swift build -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs

# Package analysis
swift package describe --type json

# Check Package.swift exists
ls Package.swift
```

### Script Flags

- `--generate-only`: Skip build, use existing symbol graphs
- `--verbose`: Show full build output
- `--be-lenient`: Continue with existing graphs if build fails
- `--help`, `-h`: Show usage information

## Code Organization Patterns

**MARK Comments Structure:** The code is organized with extensive MARK comments creating clear sections:

- `// MARK: - Config` - Configuration management
- `// MARK: - CLI Argument Parsing` - Command line interface
- `// MARK: - Orchestration Functions` - Core workflow
- `// MARK: - DocumentationGenerator` - Main generation class
- `// MARK: - Helper Functions` - Utility functions
- `// MARK: - Main Entry Point` - Script entry point

**Error Handling Pattern:** Uses structured NSError throwing with specific exit codes:

- 0: Success
- 1: Validation error (e.g., Package.swift missing)
- 2: Build error
- 3: Documentation generation error

**Configuration Pattern:** Immutable Config struct with fluent property updates when parsing flags.

## Development Workflow

1. **Testing**: Run script on actual Swift packages (no test framework)
2. **Debugging**: Use `--verbose` flag to see build output
3. **Iteration**: Use `--generate-only` for quick doc regeneration
4. **Error Recovery**: Use `--be-lenient` to work with existing symbol graphs

**Core workflow:**

1. Validate Package.swift exists in current directory
2. Extract public modules using `swift package describe --type json`
3. Build symbol graphs using Swift compiler
4. Generate Markdown documentation in `docs/` directory

## Important Constraints

- Must be run from Swift package root (where Package.swift exists)
- Only tested on macOS with Swift 6
- Uses system Swift compiler (`/usr/bin/swift`)
- Outputs to `docs/` directory by default
- Only documents public API symbols (`public` and `open` access levels)
- Automatically filters to public product modules (excludes dependencies)

## Documentation Output Format

Generates interface-style Markdown similar to Xcode's generated interfaces:

- H2 heading with module name
- Optional README content with adjusted heading levels
- H3 heading: "Public interface"
- Swift code blocks with complete interface declarations
- Symbols grouped by type (protocols → structs → classes → enums → extensions)

## No Traditional Build System

This is a standalone Swift script, not a package:

- No Package.swift file
- No Xcode project
- No testing framework
- No CI/CD configuration
- Manual testing approach only
