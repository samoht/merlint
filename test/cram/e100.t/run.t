Test bad example - should find Obj.magic usage:
  $ merlint -r E100 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    [E100] Unsafe Type Casting
    This issue means you're using unsafe type casting that can crash your program.
    Fix it by replacing Obj.magic with proper type definitions, variant types, or
    GADTs to represent different cases safely.
    - bad.ml:1:15: Use of Obj.magic (unsafe type casting)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E100 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 0 total issues
  ✗ Some checks failed. See details above.
