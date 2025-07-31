Test bad example - should find failwith (Fmt.str) patterns:
  $ merlint -r E619 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    [E619] Use Fmt.failwith Instead of failwith (Fmt.str) (1 issue)
    Use Fmt.failwith instead of failwith (Fmt.str ...). Fmt.failwith provides
    printf-style formatting directly, making the code more concise and readable.
    - bad.ml:3:0: Use Fmt.failwith instead of failwith (Fmt.str ...) - Fmt.failwith provides printf-style formatting directly
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E619 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
