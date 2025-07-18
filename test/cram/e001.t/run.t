Test bad example - should find complexity issues:
  $ merlint -r E001 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E001] High Cyclomatic Complexity
    High cyclomatic complexity makes code harder to understand and test. Consider
    breaking complex functions into smaller, more focused functions. Each function
    should ideally do one thing well.
    - bad.ml:1:0: bad.ml:1:0: Function 'check_input' has cyclomatic complexity of 7 (threshold: 5)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E001 good.ml
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
