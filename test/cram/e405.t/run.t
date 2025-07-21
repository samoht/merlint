Test bad example - should find missing value documentation:
  $ merlint -r E405 bad.mli
  File "bad.ml", line 1:
  Error: The implementation "bad.ml" does not match the interface "bad.ml": 
         The value "format" is required but not provided
         File "bad.mli", line 5, characters 0-24: Expected declaration
         The value "missing_documentation" is required but not provided
         File "bad.mli", line 7, characters 0-38: Expected declaration
  File "good.ml", line 1:
  Error: The implementation "good.ml" does not match the interface "good.ml": 
         The value "format" is required but not provided
         File "good.mli", line 7, characters 0-24: Expected declaration
         The value "process" is required but not provided
         File "good.mli", line 11, characters 0-24: Expected declaration
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (2 total issues)
    [E405] Missing Value Documentation
    All public values should have documentation explaining their purpose and
    usage. Add doc comments (** ... *) before or after value declarations in .mli
    files.
    - bad.mli:2:0: Public value 'parse' is missing documentation
    - bad.mli:7:0: Public value 'missing_documentation' is missing documentation
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E405 good.mli
  File "bad.ml", line 1:
  Error: The implementation "bad.ml" does not match the interface "bad.ml": 
         The value "format" is required but not provided
         File "bad.mli", line 5, characters 0-24: Expected declaration
         The value "missing_documentation" is required but not provided
         File "bad.mli", line 7, characters 0-38: Expected declaration
  File "good.ml", line 1:
  Error: The implementation "good.ml" does not match the interface "good.ml": 
         The value "format" is required but not provided
         File "good.mli", line 7, characters 0-24: Expected declaration
         The value "process" is required but not provided
         File "good.mli", line 11, characters 0-24: Expected declaration
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
