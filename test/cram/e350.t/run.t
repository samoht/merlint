Test bad example - should find boolean blindness:
  $ merlint -r E350 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E350] Boolean Blindness
    Functions with multiple boolean parameters are hard to use correctly. It's
    easy to mix up the order of arguments at call sites. Consider using variant
    types, labeled arguments, or a configuration record instead.
    - bad.ml:1:0: Function 'create_window' has 3 boolean parameters - consider using a variant type or record for clarity
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E350 good.ml
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
