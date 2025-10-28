# swift-interfazzle

This project is a simple, rather bare-bones, self-contained Swift script that
builds Markdown docs for a package's public interface from its Swift symbol
graphs.

Its aimed at package maintainers.

I built this for myself, first and foremost – it scratches my own itches. But it
feels kinda useful, even more so now that many of us work with LLMs, and they
need to read docs, too. And DocC and its dynamic-page nonsense is the Liquid
Glass of documentation. There, I said it.

**2025-10-28: THIS IS A WORK IN PROGRESS. USE WITH CAUTION, AT YOUR OWN RISK.**

## Overview

The `interfazzle.swift` script handles the complete documentation generation
pipeline:

1. **Validation**: Verifies Package.swift exists in the current directory
2. **Symbol Graph Generation**: Uses Swift's built-in compiler to generate
   symbol graph JSON files
3. **Markdown Conversion**: Converts symbol graphs to interface-style Markdown
   documentation

This approach replaces the old `sourcedocs` tool, which fails when the package
includes dependencies with pre-built binaries.

## Demo

See [Demo](Demo/) folder for a dummy example package containing sources (in
[Demo/Sources/](Demo/Sources/)) and generated documentation (in
[Demo/docs/](Demo/docs/)).

## Usage

### Quick Start

Generate all documentation from your Swift package root:

```bash
./interfazzle.swift
```

### Requirements

- Currently only tested on macOS w/ Swift 6 (it uses `/usr/bin/swift` under the
  hood)
- Must be run from a directory containing `Package.swift`
- Outputs to `docs/` in the current working directory
- No external dependencies required (pure Swift + Foundation)

This will:

1. Verify `Package.swift` exists in the current directory
2. Parse `Package.swift` using `swift package describe --type json` to:
   - Extract module names (your public API)
   - Discover target source paths for README integration
3. Build the project and generate symbol graphs in `.build/symbol-graphs/`
4. Convert symbol graphs to Markdown files in `docs/` with:
   - Interface-style code blocks showing the public API
   - README.md content from module source folders (if present)
   - Intelligently adjusted heading levels for proper hierarchy
   - Automatic filtering to package modules only (excludes dependencies)

## Advanced Usage

The script supports several flags for different workflows:

```bash
# Show help and all options
./interfazzle.swift --help

# Skip build, regenerate docs from existing symbol graphs (fast)
./interfazzle.swift --generate-only

# Show verbose build output for debugging
./interfazzle.swift --verbose

# Continue with existing symbol graphs if build fails
./interfazzle.swift --be-lenient

# Document specific modules only
./interfazzle.swift .build/symbol-graphs docs "Licensing,Trialling,AppUpdating"

# Use custom directories
./interfazzle.swift .build/symbols output-docs

# Combine flags
./interfazzle.swift --verbose --be-lenient
```

### Flags

- `--generate-only`: Skip build phase, use existing symbol graphs (useful for
  quick regeneration)
- `--verbose`: Show full `swift build` output (default: suppressed unless error)
- `--be-lenient`: On build failure, attempt to generate docs from existing
  symbol graphs instead of failing
- `--help`, `-h`: Show usage information

### Arguments (all optional)

- `SYMBOL_GRAPHS_DIR`: Directory for symbol graphs (default:
  `.build/symbol-graphs`)
- `OUTPUT_DIR`: Output directory for docs (default: `docs`)
- `MODULES`: Comma-separated list of modules to document (default: all public
  product modules)

**Note**: By default, the script only generates documentation for modules listed
in Package.swift's products (your public API). Dependency modules like
SwiftSyntax etc. are automatically excluded.

## Output Format

Each module generates a single Markdown file with interface-style code blocks
showing the complete public API in Swift syntax, similar to how Xcode shows
generated interfaces.

- H2 heading with module name
- Optional README content (with adjusted heading levels)
- H3 heading: "Public interface"
- Swift code blocks with complete interface declarations
- Documentation comments as triple-slash syntax above each symbol

### Structure

- **H2**: Module name (`## Module \`ModuleName\``)
- **Optional**: README content from module source folder (e.g.,
  `Sources/ModuleName/README.md`)
  - Headings automatically adjusted so the highest level becomes H3
  - Maintains relative hierarchy of all headings
- **H3**: "Public interface" heading
- **Code blocks**: Swift interface declarations grouped by type
  - Protocols → Structs → Classes → Enums → Extensions → Macros → Functions
  - Nested types rendered within parent declarations
  - Documentation comments as triple-slash (`///`) comments above declarations

### README Integration

If a module folder contains a `README.md` file, its content is automatically
included after the module heading. The script:

1. Removes duplicate module name headings (e.g., `# ModuleName`)
2. Adjusts heading levels intelligently:
   - Finds the highest heading level in the README (e.g., `##` = level 2)
   - Shifts it to H3 to fit under the module's H2
   - Applies the same shift to all other headings to maintain hierarchy
3. Example: README with `##` and `###` → becomes `###` and `####` in output

## Script

### `interfazzle.swift`

Unified Swift script that handles the complete documentation generation
pipeline.

**Features**:

- **Validation**: Checks for Package.swift in current directory
- **Orchestration**: Builds symbol graphs and generates documentation in one
  command
- **Filtering**: Automatically filters to public product modules (excludes
  dependencies)
- **Flags**: `--generate-only`, `--verbose`, `--be-lenient` for different
  workflows
- **Customization**: Optional custom directories and module filtering
- **README Integration**: Automatically includes README.md from module source
  folders
- **Heading Adjustment**: Intelligently adjusts README heading levels to
  maintain hierarchy
- **Interface-style Output**: Generates code blocks like Xcode's generated
  interfaces
- **Symbol Grouping**: Organizes by type (protocols → structs → classes → enums
  → extensions)
- **Nested Types**: Handles nested types with proper indentation
- **Protocol Consolidation**: Shows all protocol conformances in main class
  declarations
- **Doc Comments**: Renders documentation comments as triple-slash (`///`)
  syntax
- **Error Handling**: Clear error messages with appropriate exit codes

**Exit Codes**:

- `0`: Success
- `1`: Validation error (e.g., Package.swift not found)
- `2`: Build error (when not using `--be-lenient`)
- `3`: Documentation generation error

## How It Works

### Symbol Graphs

Swift's compiler can emit "symbol graphs" - JSON files containing all public API
information:

- Types (classes, structs, enums, protocols)
- Properties and methods
- Documentation comments
- Declaration signatures
- Relationships between symbols

### Conversion Process

The `interfazzle.swift` script's Markdown generation phase:

1. **Reads** symbol graph JSON files from `.build/symbol-graphs/`
2. **Filters** to public product modules by default (excludes dependencies)
3. **Filters** to public API symbols (`public` and `open` access levels,
   excludes internal/private/synthesized)
4. **Groups** symbols by:
   - Type (protocols, structs, classes, enums, extensions)
   - Nesting (properties, methods, etc. under parent types)
5. **Generates** one Markdown file per module with all content consolidated:
   - `ModuleName.md` containing all symbols for that module
   - Interface-style code blocks showing the complete public API
   - Optional README content with intelligently adjusted heading levels

## Why Not SourceDocs?

[SourceDocs](https://github.com/eneko/SourceDocs) failed for me on projects:

1. It uses SourceKit, which crashes when dependencies include pre-built binaries
2. Symbol graphs are compiler-generated, so they handle all valid Swift packages
3. Symbol graphs are the official way Apple recommends for documentation tooling

The above conclusions might be wrong, I'm still a noob in a lot of regards when
it comes to Swift.

### Differences from SourceDocs Output

The generated documentation differs from SourceDocs in structure and format:

1. **Interface-style code blocks**: Shows complete Swift interface in code
   blocks (like Xcode's generated interfaces) instead of individual sections per
   symbol
2. **Consolidated files**: One `ModuleName.md` file per module instead of
   folder-per-module with multiple files
3. **Minimal headings**: Just module name (H2) and "Public interface" (H3), with
   all API in code blocks
4. **README integration**: Automatically includes README.md from module source
   folders with intelligent heading adjustment
5. **Protocol consolidation**: Shows all protocol conformances (including from
   extensions) in the main class declaration
6. **Nested type rendering**: Nested types appear within their parent
   declarations, maintaining proper Swift syntax

The interface-style format is more compact, easier to read, and better reflects
how developers actually view APIs in Xcode.

## Future Improvements

Potential enhancements:

- [ ] Make it a real package, maybe?
- [ ] 
- [ ] Generate cross-reference links between types
- [ ] Add availability information (iOS 16+, macOS 13+, etc.) to declarations

## Troubleshooting

### "Cannot read symbol graphs directory"

Run the script without `--generate-only` to build symbol graphs first, or
manually build them:

```bash
swift build -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs
```

### "Package.swift not found in current directory"

The script must be run from the root of a Swift package (where Package.swift is
located).

### Missing symbols in output

Only public API symbols (`public` and `open` access levels) are documented.
Internal/private/fileprivate symbols are intentionally excluded.

### README not being included

The script looks for `README.md` in the target's source path as defined in
`Package.swift`. If your README isn't being included:

1. Verify the file is named exactly `README.md` (case-sensitive)
2. Check it's in the module's source directory (e.g.,
   `Sources/ModuleName/README.md`)
3. Verify the target path in Package.swift matches where the README is located

### Formatting issues

The script uses Swift's declaration fragments directly. If formatting looks odd,
check the symbol graph JSON to see what the compiler emits.

### Build errors blocking documentation generation

Use `--be-lenient` to generate docs from existing symbol graphs even if the
build fails:

```bash
./interfazzle.swift --be-lenient
```

### Dependency modules appearing in output

This shouldn't happen with the current version. The script automatically filters
to only public product modules. If you see dependency docs being generated,
please report it as a bug.

### Regenerating docs quickly after edits

Use `--generate-only` to skip the build phase and regenerate docs from existing
symbol graphs:

```bash
./interfazzle.swift --generate-only
```

This is much faster when you've only changed documentation comments or README
files.

## Author

Carlo Zottmann, <carlo@zottmann.dev>, https://c.zottmann.dev,
https://github.com/czottmann

> ### 💡 Did you know?
>
> I make Shortcuts-related macOS & iOS productivity apps like
> [Actions For Obsidian](https://actions.work/actions-for-obsidian),
> [Browser Actions](https://actions.work/browser-actions) (which adds Shortcuts
> support for several major browsers), and
> [BarCuts](https://actions.work/barcuts) (a surprisingly useful contextual
> Shortcuts launcher). Check them out!
