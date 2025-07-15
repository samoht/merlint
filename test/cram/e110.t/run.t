Test bad example - should find silenced warning:
  $ merlint -r E110 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E110] Silenced Compiler Warnings
    This issue means you're hiding compiler warnings that indicate potential
    problems. Fix it by removing warning silencing attributes and addressing the
    underlying issues that trigger the warnings.
    - bad.ml:1:0: Warning '32' is silenced
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E110 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues
  ✓ All checks passed!
