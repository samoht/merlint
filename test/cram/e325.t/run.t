Test bad example - should find bad function naming convention:
  $ merlint -r E325 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E325] Function Naming Convention (2 issues)
    Functions that return option types should be prefixed with 'find_', while
    functions that return non-option types should be prefixed with 'get_'. This
    convention helps communicate the function's behavior to callers.
    - bad.ml:1:0: Function 'get_user' naming convention: consider 'find_user'
    - bad.ml:2:0: Function 'find_name' naming convention: consider 'get_name'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E325 good.ml
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
