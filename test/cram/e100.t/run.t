Test bad example - should find Obj.magic usage:
  $ merlint -r E100 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E100] No Obj.magic
    Obj.magic completely bypasses OCaml's type system and is extremely dangerous.
    It can lead to segmentation faults, data corruption, and unpredictable
    behavior. Instead, use proper type definitions, GADTs, or polymorphic
    variants. If you absolutely must use unsafe features, document why and isolate
    the usage.
    - bad.ml:1:15: Usage of Obj.magic detected - this is extremely unsafe
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues (applied 1 rules)
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
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
