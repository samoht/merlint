Test bad example - should find catch-all exception handler:
  $ merlint -r E105 bad.ml
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
  $ merlint -r E105 good.ml
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
