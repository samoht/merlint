Test simple functions with low complexity
  $ merlint samples/simple.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/simple.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test function with high cyclomatic complexity
  $ merlint samples/complex.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/complex.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test long function detection
  $ merlint samples/long_function.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E005] Long Functions
    This issue means your functions are too long and hard to read. Fix them by
    extracting logical sections into separate functions with descriptive names.
    Note: Functions with pattern matching get additional allowance (2 lines per
    case). Pure data structures (lists, records) are also exempt from length
    checks. For better readability, consider using helper functions for complex
    logic. Aim for functions under 50 lines of actual logic.
    - long_function.ml:2:0: Function 'very_long_function' is too long (54 lines, threshold: 50)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/long_function.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  [1]

Test naming conventions
  $ merlint samples/bad_names.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E310] Value Naming Convention
    This issue means your value names don't follow OCaml naming conventions. Fix
    them by renaming to snake_case (e.g., myValue → my_value).
    - samples/bad_names.ml:4:6: Value 'myFunction' should be 'my_function'
    - samples/bad_names.ml:9:4: Value 'checkValue' should be 'check_value'
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/bad_names.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 4 total issues
  ✗ Some checks failed. See details above.
  [1]

Test documentation rules
  $ merlint samples/missing_docs.mli
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (1 total issues)
    [E400] Missing Module Documentation
    This issue means your modules lack documentation making them hard to
    understand. Fix it by adding module documentation at the top of .mli files
    with a brief summary and description of the module's purpose.
    - samples/missing_docs.mli:1:1: Module 'missing_docs' is missing documentation comment
  ✗ Project Structure (1 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test style rules - Obj.magic
  $ merlint samples/bad_style.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    [E100] Unsafe Type Casting
    This issue means you're using unsafe type casting that can crash your program.
    Fix it by replacing Obj.magic with proper type definitions, variant types, or
    GADTs to represent different cases safely.
    - samples/bad_style.ml:2:16: Use of Obj.magic (unsafe type casting)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/bad_style.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  [1]

Test style rules - Str module
  $ merlint samples/uses_str.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/uses_str.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test Printf/Format module usage
  $ merlint samples/uses_printf.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    [E205] Outdated Printf/Format Modules
    This is a style suggestion. While Printf and Format are part of OCaml's
    standard library and perfectly fine to use, the Fmt library offers additional
    features like custom formatters and better composability. Consider using Fmt
    for new code, but Printf/Format remain valid choices for many use cases.
    - samples/uses_printf.ml:2:2: Use Fmt module instead of Printf
    - samples/uses_printf.ml:3:2: Use Fmt module instead of Printf
    - samples/uses_printf.ml:6:2: Use Fmt module instead of Format
    - samples/uses_printf.ml:7:2: Use Fmt module instead of Format
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/uses_printf.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 6 total issues
  ✗ Some checks failed. See details above.
  [1]

Test catch-all exception handler
  $ merlint samples/catch_all.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
    - samples:1:1: missing .ocamlformat file
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - samples/catch_all.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]
