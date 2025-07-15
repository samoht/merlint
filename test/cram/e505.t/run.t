Test bad example - should find missing interface file:
  $ merlint -r E505 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E505] Missing Interface Files
    This issue means your modules lack interface files making their public API
    unclear. Fix it by creating .mli files that document which functions and types
    should be public. Copy public signatures from the .ml file and remove private
    ones.
    - bad.ml:1:1: missing interface file
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E505 good.ml good.mli
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues
  ✓ All checks passed!
