Test bad example - should find mutable state:
  $ merlint -r E340 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (2 total issues)
    [E340] Inline Error Construction
    This issue means you're constructing errors inline instead of using helper
    functions. Fix by defining err_* functions at the top of your file for each
    error case. This promotes consistency, enables easy error message updates, and
    makes error handling patterns clearer.
    - bad.ml:3:0: Error 'Error (Fmt.str ...)' should use helper function 'err_*'
    - bad.ml:6:0: Error 'Error (Fmt.str ...)' should use helper function 'err_*'
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E340 good.ml
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
