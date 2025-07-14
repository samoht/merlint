Test bad example - should find used underscore binding:
  $ merlint -r E325 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E325] Function Naming Pattern
    This issue means your function names don't match their return types. Fix them
    by using consistent naming: get_* for extraction (returns value directly),
    find_* for search (returns option type).
    - bad.ml:1:0: Function 'get_user' should be 'find_user'
    - bad.ml:2:0: Function 'find_name' should be 'get_name'
  ✓ Documentation (0 total issues)
  ✗ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
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
  ✗ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 0 total issues
  ✗ Some checks failed. See details above.
