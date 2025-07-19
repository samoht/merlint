Test bad example - should find bad value naming:
  $ merlint -r E310 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E310] Value Naming Convention
    Values and function names should use snake_case (e.g., find_user,
    create_channel). Short, descriptive, and lowercase with underscores. This is
    the standard convention in OCaml for values and functions.
    - bad.ml:2:4: Value 'myValue' should use snake_case: 'my_value'
    - bad.ml:3:4: Value 'getUserName' should use snake_case: 'get_user_name'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E310 good.ml
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
