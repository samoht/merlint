Test simple functions with low complexity
  $ merlint samples/simple.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/simple.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
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
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/complex.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
  [1]

Test long function detection
  $ merlint samples/long_function.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    ✗ Complexity rules (complexity ≤10, length ≤50, nesting ≤3) (1 issues)
      [E005] long_function.ml:2:0: Function 'very_long_function' is 54 lines long
             (threshold: 50)
    ✓ Warning rules (no silenced warnings) (0 issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/long_function.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E005] Long Functions
    This issue means your functions are too long and hard to read. Fix them by
    extracting logical sections into separate functions with descriptive names.
    Note: Large pattern matching blocks are acceptable - functions with pattern
    matching get double the line limit when they have more than 10 cases. For
    better readability, consider using a helper function for each complex case.
    Aim for functions under 50 lines otherwise.
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
  [1]

Test naming conventions
  $ merlint samples/bad_names.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (5 total issues)
    ✗ Naming conventions (snake_case) (5 issues)
      [E300] samples/bad_names.ml:3:7: Variant 'MyModule' should be 'My_module'
      [E310] samples/bad_names.ml:4:6: Value 'myFunction' should be 'my_function'
      [E300] samples/bad_names.ml:7:32: Variant 'ProcessingData' should be
             'Processing_data'
      [E300] samples/bad_names.ml:7:14: Variant 'WaitingForInput' should be
             'Waiting_for_input'
      [E310] samples/bad_names.ml:9:4: Value 'checkValue' should be 'check_value'
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/bad_names.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 7 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E300] Variant Naming Convention
    This issue means your variant constructors don't follow OCaml naming
    conventions. Fix them by renaming to Snake_case (e.g., MyVariant →
    My_variant).
  
  ❌ BAD:
  ```ocaml
  type status = 
    | WaitingForInput    (*
    CamelCase *)
    | ProcessingData
    | errorOccurred      (* lowerCamelCase
    *)
  ```
  
  ✅ GOOD:
  ```ocaml
  type status = 
    | Waiting_for_input  (* Snake_case
    *)
    | Processing_data
    | Error_occurred
  ```
  
  [E310] Value Naming Convention
    This issue means your value names don't follow OCaml naming conventions. Fix
    them by renaming to snake_case (e.g., myValue → my_value).
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
  [1]

Test documentation rules
  $ merlint samples/missing_docs.mli
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (1 total issues)
    ✗ Documentation rules (module docs) (1 issues)
      [E400] samples/missing_docs.mli:1:0: Module 'missing_docs' missing
             documentation comment
  ✗ Project Structure (1 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (1 issues)
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E400] Missing Module Documentation
    This issue means your modules lack documentation making them hard to
    understand. Fix it by adding module documentation at the top of .mli files
    with a brief summary and description of the module's purpose.
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  [1]

Test style rules - Obj.magic
  $ merlint samples/bad_style.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (1 issues)
      [E100] samples/bad_style.ml:2:16: Never use Obj.magic
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/bad_style.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E100] Unsafe Type Casting
    This issue means you're using unsafe type casting that can crash your program.
    Fix it by replacing Obj.magic with proper type definitions, variant types, or
    GADTs to represent different cases safely.
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
  [1]

Test style rules - Str module
  $ merlint samples/uses_str.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (4 issues)
      [E200] samples/uses_str.ml:2:31: Use Re module instead of Str
      [E200] samples/uses_str.ml:2:20: Use Re module instead of Str
      [E200] samples/uses_str.ml:6:32: Use Re module instead of Str
      [E200] samples/uses_str.ml:6:12: Use Re module instead of Str
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/uses_str.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 6 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E200] Outdated Str Module
    This issue means you're using the outdated Str module for regular expressions.
    Fix it by switching to the modern Re module: add 're' to your dune
    dependencies and replace Str functions with Re equivalents.
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
  [1]

Test Printf/Format module usage
  $ merlint samples/uses_printf.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (4 issues)
      [E205] samples/uses_printf.ml:2:2: Use Fmt module instead of Printf
      [E205] samples/uses_printf.ml:3:2: Use Fmt module instead of Printf
      [E205] samples/uses_printf.ml:6:2: Use Fmt module instead of Format
      [E205] samples/uses_printf.ml:7:2: Use Fmt module instead of Format
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/uses_printf.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 6 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E205] Outdated Printf/Format Modules
    This issue means you're using outdated Printf/Format modules for formatting.
    Fix it by switching to the modern Fmt module: add 'fmt' to your dune
    dependencies and replace Printf/Format functions with Fmt equivalents.
  
  ❌
    BAD:
  ```ocaml
  let error_msg = Printf.sprintf "Error: %s at line %d" msg
    line
  let () = Printf.printf "Processing %d items...\n" count
  ```
  
  ✅
    GOOD:
  ```ocaml
  let error_msg = Fmt.str "Error: %s at line %d" msg line
  let ()
    = Fmt.pr "Processing %d items...@." count
  
  (* Even better with custom
    formatters *)
  let pp_error ppf (msg, line) = 
    Fmt.pf ppf "Error: %s at line
    %d" msg line
  ```
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
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
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      [E505] samples/catch_all.ml:1:1: missing interface file
      [E500] (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
  [E500] Missing Code Formatter
    This issue means your project lacks consistent code formatting. Fix it by
    creating a .ocamlformat file in your project root with 'profile = default' and
    a version number to ensure consistent formatting.
  
  [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
  [1]
