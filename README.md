# Cyclomatic

OCaml cyclomatic complexity analyzer using Merlin.

## Installation

```bash
opam install .
```

## Usage

```bash
# Analyze all .ml files in current dune project
cyclomatic

# Analyze specific files
cyclomatic file1.ml file2.ml

# Analyze all .ml files in specific directories
cyclomatic lib/ src/
```

Options:
- `--max-complexity N` (default: 10) - Maximum allowed cyclomatic complexity
- `--max-length N` (default: 50) - Maximum allowed function length in lines

## Example

```bash
# Check entire project with default thresholds
cyclomatic

# Check specific directory
cyclomatic lib/

# Check specific files with custom thresholds
cyclomatic --max-complexity 15 --max-length 100 src/*.ml
```

The tool will exit with code 1 if any violations are found.

Violations are sorted by priority:
1. Complexity violations (highest complexity first)
2. Length violations (longest functions first)