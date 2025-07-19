Test bad example - should find error pattern usage:
  $ merlint -r E340 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (2 total issues)
    [E340] Error Pattern Detection
    Using raw Error constructors with Fmt.str can lead to inconsistent error
    messages. Consider creating error helper functions (prefixed with 'err_') that
    encapsulate common error patterns and provide consistent formatting.
    - bad.ml:3:0: bad.ml:3:0: Found 'Error (Fmt.str ...)' pattern - consider using 'err_*' helper functions for consistent error handling
    - bad.ml:6:0: bad.ml:6:0: Found 'Error (Fmt.str ...)' pattern - consider using 'err_*' helper functions for consistent error handling
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rules)
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
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
