# Merlint

An opinionated OCaml linter that enforces modern OCaml coding conventions.

## Features

Merlint checks for:

### Complexity
- **Cyclomatic complexity**: Functions should have complexity ≤ 10
- **Function length**: Functions should be ≤ 50 lines  
- **Nesting depth**: Code should not nest deeper than 3 levels

### Naming Conventions
- **Modules**: Must use snake_case (e.g., `user_profile`)
- **Variants**: Must use Snake_case (e.g., `Waiting_for_input`)
- **Values/Functions**: Must use snake_case
- **Types**: Must use snake_case (primary type should be `t`)

### Documentation
- **MLI files**: Must have module-level documentation comment

### Code Style
- **No Obj.magic**: Never use `Obj.magic`
- **No catch-all**: Avoid `try ... with _ -> ...`
- **Use Re not Str**: Use `Re` module instead of `Str` for regular expressions

## Installation

```bash
opam install . --deps-only
dune build
dune install
```

## Usage

```bash
# Analyze entire project
merlint

# Analyze specific files or directories
merlint src/ lib/
merlint src/parser.ml
```

## Example Output

```
src/parser.ml:45:2: Function 'parse_expr' has cyclomatic complexity of 15 (threshold: 10)
src/types.ml:12:4: Module 'myModule' should be 'my_module'
src/utils.ml:33:8: Never use Obj.magic
src/api.mli:1:0: Module 'api' missing documentation comment
src/types.ml:8:2: Variant 'waitingForInput' should be 'Waiting_For_Input'
```

## Philosophy

Merlint enforces best practices for OCaml development, focusing on:
- Code clarity and maintainability
- Consistent naming conventions
- Proper documentation
- Safe coding practices

## Development

```bash
# Run tests
dune test

# Format code
dune fmt
```