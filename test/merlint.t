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
      samples/simple.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/simple.mli (copy public signatures from samples/simple.ml)
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
      samples/complex.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/complex.mli (copy public signatures from samples/complex.ml)
  [1]

Test long function detection
  $ merlint samples/long_function.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    ✗ Complexity rules (complexity ≤10, length ≤50, nesting ≤3) (1 issues)
      long_function.ml:2:0: Function 'very_long_function' is 54 lines long (threshold: 50)
    ✓ Warning rules (no silenced warnings) (0 issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/long_function.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Split these long functions by extracting logical sections into separate functions:
       long_function.ml:2:0: function very_long_function
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/long_function.mli (copy public signatures from samples/long_function.ml)
  [1]

Test naming conventions
  $ merlint samples/bad_names.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (5 total issues)
    ✗ Naming conventions (snake_case) (5 issues)
      samples/bad_names.ml:3:7: Variant 'MyModule' should be 'My_module'
      samples/bad_names.ml:4:6: Value 'myFunction' should be 'my_function'
      samples/bad_names.ml:7:32: Variant 'ProcessingData' should be 'Processing_data'
      samples/bad_names.ml:7:14: Variant 'WaitingForInput' should be 'Waiting_for_input'
      samples/bad_names.ml:9:4: Value 'checkValue' should be 'check_value'
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/bad_names.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 7 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Rename these variant constructors:
       samples/bad_names.ml:3:7: MyModule → My_module
       samples/bad_names.ml:7:14: WaitingForInput → Waiting_for_input
       samples/bad_names.ml:7:32: ProcessingData → Processing_data
  
    • Rename these values:
       samples/bad_names.ml:4:6: let myFunction → let my_function
       samples/bad_names.ml:9:4: let checkValue → let check_value
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/bad_names.mli (copy public signatures from samples/bad_names.ml)
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
      samples/missing_docs.mli:1:0: Module 'missing_docs' missing documentation comment
  ✗ Project Structure (1 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (1 issues)
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Add module documentation at the top of these .mli files:
       samples/missing_docs.mli:1: Add documentation for module missing_docs
  
       Template:
       (** Brief one-line summary
  
           This module provides types and functions for detailed description of what this module does. *)
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  [1]

Test style rules - Obj.magic
  $ merlint samples/bad_style.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (1 issues)
      samples/bad_style.ml:2:16: Never use Obj.magic
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/bad_style.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Replace all Obj.magic calls with proper type definitions. Define a variant type or use GADTs to represent the different cases safely.
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/bad_style.mli (copy public signatures from samples/bad_style.ml)
  [1]

Test style rules - Str module
  $ merlint samples/uses_str.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (4 issues)
      samples/uses_str.ml:2:31: Use Re module instead of Str
      samples/uses_str.ml:2:20: Use Re module instead of Str
      samples/uses_str.ml:6:32: Use Re module instead of Str
      samples/uses_str.ml:6:12: Use Re module instead of Str
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/uses_str.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 6 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Replace all Str module usage:
       1. Add 're' to your dune dependencies: (libraries ... re)
       2. Replace Str.regexp with Re.compile (Re.str ...)
       3. Replace Str.string_match with Re.execp
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/uses_str.mli (copy public signatures from samples/uses_str.ml)
  [1]

Test Printf/Format module usage
  $ merlint samples/uses_printf.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (4 issues)
      samples/uses_printf.ml:2:2: Use Fmt module instead of Printf
      samples/uses_printf.ml:3:2: Use Fmt module instead of Printf
      samples/uses_printf.ml:6:2: Use Fmt module instead of Format
      samples/uses_printf.ml:7:2: Use Fmt module instead of Format
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/uses_printf.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 6 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Replace Printf/Format module usage with Fmt:
       1. Add 'fmt' to your dune dependencies: (libraries ... fmt)
       2. Replace Printf.printf with Fmt.pr
       3. Replace Printf.sprintf with Fmt.str
       4. Replace Format.printf with Fmt.pr
       5. Replace Format.asprintf with Fmt.str
       Example: Fmt.pr "Hello %s!@." name
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/uses_printf.mli (copy public signatures from samples/uses_printf.ml)
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
      samples/catch_all.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  
  💡 Fix hints:
  
    • Create file '.ocamlformat' in project root with:
       profile = default
       version = 0.26.1
  
    • Create these interface files:
       Create samples/catch_all.mli (copy public signatures from samples/catch_all.ml)
  [1]
