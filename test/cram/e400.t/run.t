Test bad example - should find missing module documentation:
  $ merlint -r E400 bad.ml
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

Test good example - should find no issues:
  $ merlint -r E400 good.ml
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
