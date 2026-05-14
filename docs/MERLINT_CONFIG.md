# Merlint Configuration Guide

Merlint reads its configuration from a `merlint.toml` file in the
project root. The file is parsed as TOML 1.1 and supports two kinds
of entries: top-level settings keys, and `[[rules]]` blocks that
exclude specific rules for files matching a glob pattern.

## Configuration File Location

Merlint looks for `merlint.toml` in the project root. If no
configuration file is found, default settings are used.

## Configuration Sections

### Settings

General configuration options for merlint rules. Use kebab-case for
all setting names.

```toml
# Complexity rules
max-complexity = 15              # Maximum cyclomatic complexity (default: 10)
max-function-length = 100        # Maximum function length in lines (default: 50)
max-nesting = 5                  # Maximum nesting depth (default: 4)
exempt-data-definitions = true   # Don't check length for pure data (default: true)

# Naming rules
max-underscores-in-name = 2      # Maximum underscores allowed (default: 1)
min-name-length-underscore = 5   # Minimum length for underscore rules (default: 5)

# Style rules
allow-obj-magic = false          # Allow Obj.magic usage (default: false)
allow-str-module = false         # Allow Str module usage (default: false)
allow-catch-all-exceptions = false # Allow catch-all exception handlers (default: false)

# Format rules
require-ocamlformat-file = true  # Require .ocamlformat file (default: true)
require-mli-files = true         # Require .mli files for .ml files (default: true)
```

### Rules

Each `[[rules]]` block excludes the listed rules for files matching
the `files` pattern. Useful when certain rules don't fit a specific
module or when you have intentional patterns that trigger false
positives.

```toml
# Single glob
[[rules]]
files = "lib/prose*.ml"
exclude = ["E330"]               # Exclude redundant module name check

# Same exclude over many specific files -- list form
[[rules]]
files = [
  "lib/color.ml*",
  "lib/margin.ml*",
  "lib/padding.ml*",
]
exclude = ["E330"]

# Test files don't need comprehensive documentation
[[rules]]
files = "test/**/*.ml"
exclude = ["E400", "E410"]

# Generated files
[[rules]]
files = "**/*_gen.ml"
exclude = ["E100", "E105", "E330"]
```

Each entry in a list-form `files` is treated as its own pattern; the
block above is equivalent to writing three separate `[[rules]]`
blocks with the same `exclude`. Use the list form when one exclude
covers a known set of files but a wider glob would catch siblings
you do want flagged (e.g. CSS-shaped libraries with one module per
property name).

## Pattern Syntax

File patterns support standard glob syntax:

- `*` — matches any characters except `/`
- `**` — matches any number of directories
- `?` — matches any single character
- `[abc]` — matches any character in the brackets

## Example Configuration

A complete `merlint.toml` for a typical project:

```toml
# Relax complexity limits slightly
max-complexity = 15
max-function-length = 80

# Stricter naming conventions
max-underscores-in-name = 1

# Don't allow Obj.magic globally
allow-obj-magic = false

# CSS-like utility modules use intentional prefixes; one block, many files
[[rules]]
files = [
  "lib/color.ml*",
  "lib/margin.ml*",
  "lib/padding.ml*",
  "lib/prose.ml*",
  "lib/typography.ml*",
]
exclude = ["E330"]

# Test files don't need comprehensive documentation
[[rules]]
files = "test/**/*.ml*"
exclude = ["E400", "E410"]

# Generated code is exempt from style rules
[[rules]]
files = "**/*_gen.ml"
exclude = ["E100", "E105", "E110", "E200", "E205", "E330"]

# FFI bindings may need Obj.magic
[[rules]]
files = "lib/ffi/*.ml"
exclude = ["E310"]
```

## Command Line Override

Command line flags take precedence over configuration file settings.
For example:

```bash
# This will run only E100, ignoring exclusions in merlint.toml
merlint -r E100

# This will run all rules except E330, regardless of merlint.toml
merlint -r all-E330
```
