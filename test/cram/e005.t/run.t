Test bad example - should find function length issues:
  $ merlint -r E005 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E005] Long Functions
    This issue means your functions are too long and hard to read. Fix them by
    extracting logical sections into separate functions with descriptive names.
    Note: Functions with pattern matching get additional allowance (2 lines per
    case). Pure data structures (lists, records) are also exempt from length
    checks. For better readability, consider using helper functions for complex
    logic. Aim for functions under 50 lines of actual logic.
    - bad.ml:1:0: Function 'process_all_data' is 55 lines long (threshold: 50)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E005 good.ml
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
