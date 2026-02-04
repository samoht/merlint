# Merlint Configuration Guide

Merlint can be configured using a `.merlint` file in your project root. The configuration file uses a YAML-like syntax with support for settings and rule exclusions.

## Configuration File Location

Merlint looks for a `.merlint` file in the project root directory. If no configuration file is found, default settings are used.

## Configuration Sections

### Settings

General configuration options for merlint rules. Use kebab-case for all setting names.

```yaml
settings:
  # Complexity rules
  max-complexity: 15              # Maximum cyclomatic complexity (default: 10)
  max-function-length: 100        # Maximum function length in lines (default: 50)
  max-nesting: 5                   # Maximum nesting depth (default: 4)
  exempt-data-definitions: true   # Don't check length for pure data (default: true)
  
  # Naming rules
  max-underscores-in-name: 2      # Maximum underscores allowed (default: 1)
  min-name-length-underscore: 5   # Minimum length for underscore rules (default: 5)
  
  # Style rules
  allow-obj-magic: false           # Allow Obj.magic usage (default: false)
  allow-str-module: false          # Allow Str module usage (default: false)
  allow-catch-all-exceptions: false # Allow catch-all exception handlers (default: false)
  
  # Format rules
  require-ocamlformat-file: true   # Require .ocamlformat file (default: true)
  require-mli-files: true          # Require .mli files for .ml files (default: true)
```

### Rules

Exclude specific rules for files matching glob patterns. This is useful when certain rules don't make sense for specific modules or when you have intentional patterns that trigger false positives.

```yaml
rules:
  # Exclude specific rules for files matching patterns
  - files: lib/prose*.ml
    exclude: [E330]              # Exclude redundant module name check
  
  - files: lib/color.ml*       # Matches lib/color.ml and lib/color.mli
    exclude: [E330]
  
  - files: test/**/*.ml        # All ML files in test directory and subdirectories
    exclude: [E400, E410]       # Exclude documentation rules for tests
  
  - files: **/*_gen.ml         # Generated files
    exclude: [E100, E105, E330] # Exclude multiple rules
```

## Pattern Syntax

File patterns support standard glob syntax:
- `*` - matches any characters except `/`
- `**` - matches any number of directories
- `?` - matches any single character
- `[abc]` - matches any character in the brackets

## Example Configuration

Here's a complete example `.merlint` file:

```yaml
# Merlint configuration for a typical OCaml project

settings:
  # Relax complexity limits slightly
  max-complexity: 15
  max-function-length: 80
  
  # Stricter naming conventions
  max-underscores-in-name: 1
  
  # Allow Obj.magic in specific cases (use rules for specific files)
  allow-obj-magic: false

rules:
  # CSS-like utility modules use intentional prefixes
  - files: lib/prose*.ml
    exclude: [E330]
  
  - files: lib/tailwind*.ml
    exclude: [E330]
  
  # Test files don't need comprehensive documentation
  - files: test/**/*.ml*
    exclude: [E400, E410]
  
  # Generated code is exempt from style rules
  - files: **/*_gen.ml
    exclude: [E100, E105, E110, E200, E205, E330]
  
  # FFI bindings may need Obj.magic
  - files: lib/ffi/*.ml
    exclude: [E310]
```

## Command Line Override

Command line flags take precedence over configuration file settings. For example:

```bash
# This will run only E100, ignoring exclusions in .merlint
merlint -r E100

# This will run all rules except E330, regardless of .merlint
merlint -r all-E330
```