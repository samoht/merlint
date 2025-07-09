# Merlint Design Document

## Overview

Merlint is an opinionated OCaml linter that enforces modern coding conventions.

## Rules

### Core Philosophy
- **no_obj_magic**: NEVER USE Obj.magic (breaks type safety)

### Module and Interface Design
- **mli_documentation**: Every .mli file must begin with top-level doc comment
- **exported_value_docs**: Document every exported value in .mli files
- **doc_style_functions**: Use `[function_name arg1 arg2] is ...` pattern
- **abstract_types**: Keep types abstract when possible

### Standard Interfaces
- **standard_functions**: For modules with type `t`, check for standard functions:
  - `v` for pure constructors
  - `create` for side-effecting constructors
  - `pp` for pretty-printing
  - `equal` for equality
  - `compare` for comparison
  - `of_json`/`to_json` for JSON conversion

### Error Handling
- **use_result**: Use result type for recoverable errors, not exceptions
- **no_catch_all**: Never use `try ... with _ -> ...`
- **no_str_module**: Use Re module instead of Str for regular expressions

### Naming Conventions
- **file_naming**: Lowercase with underscores (e.g., `user_profile.ml`)
- **module_naming**: Lowercase with underscores (e.g., `user_profile`)
- **type_naming**: Primary type is `t`, identifiers are `id`
- **variant_snake_case**: Use Snake_case for variants (e.g., `Waiting_for_input`)
- **value_naming**: Lowercase with underscores (e.g., `find_user`)

### Function Design
- **small_functions**: Keep functions small and focused
- **avoid_deep_nesting**: Avoid more than 2-3 levels of match/if nesting

### Logging
- **log_source**: Each module should define its own log source
- **structured_logging**: Use tags for structured context

### Existing Rules (keep these)
- **cyclomatic_complexity**: Functions should have complexity ≤ 10
- **function_length**: Functions should be ≤ 50 lines

## CLI Usage

```bash
# Run on current project
merlint

# Run on specific files/directories
merlint src/ lib/
```

## Output

```
src/parser.ml:45:2: error: Never use Obj.magic
src/user.mli:1:0: error: Missing module documentation comment
src/types.ml:12:4: error: Variant 'waitingForInput' should be 'Waiting_for_input'
src/api.ml:89:2: error: Avoid catch-all exception handler
```