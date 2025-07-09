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
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test function with high cyclomatic complexity
  $ merlint samples/complex.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    ✗ Complexity rules (complexity ≤10, length ≤50, nesting ≤3) (1 issues)
      complex.ml:8:0: Function 'process_command' has cyclomatic complexity of 14 (threshold: 10)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/complex.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  [1]

Test long function detection
  $ merlint samples/long_function.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    ✗ Complexity rules (complexity ≤10, length ≤50, nesting ≤3) (1 issues)
      long_function.ml:2:0: Function 'very_long_function' is 54 lines long (threshold: 50)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/long_function.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
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
  
  Summary: ✗ 7 total issues
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
    ✗ Documentation rules (module docs) (1 issues)
      samples/missing_docs.mli:1:0: Module 'missing_docs' missing documentation comment
  ✗ Project Structure (1 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (1 issues)
      (project): Missing .ocamlformat file for consistent formatting
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test style rules - Obj.magic
  $ merlint samples/bad_style.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (1 issues)
      bad_style.ml:2:16: Never use Obj.magic
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/bad_style.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  
  Summary: ✗ 3 total issues
  ✗ Some checks failed. See details above.
  [1]

Test style rules - Str module
  $ merlint samples/uses_str.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    ✗ Style rules (no Obj.magic, no Str, no catch-all) (4 issues)
      uses_str.ml:2:31: Use Re module instead of Str
      uses_str.ml:2:20: Use Re module instead of Str
      uses_str.ml:6:32: Use Re module instead of Str
      uses_str.ml:6:12: Use Re module instead of Str
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/uses_str.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  
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
    ✗ Format rules (.ocamlformat, .mli files) (2 issues)
      samples/catch_all.ml:1:1: missing interface file
      (project): Missing .ocamlformat file for consistent formatting
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]
