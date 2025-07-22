Test bad example - should find global mutable state:
  $ merlint -r E351 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (2 total issues)
    [E351] Global Mutable State (2 issues)
    Global mutable state makes programs harder to reason about and test. A good
    design pattern is to create an init value and pass it around as a parameter
    instead of accessing global refs. This makes data flow explicit and functions
    easier to test. If mutation is necessary, consider using local state within
    functions or returning updated values.
    - bad.ml:2:0: Global mutable state 'counter' of type 'ref' detected - instead of accessing a global ref, consider creating an init value and passing it through function parameters
    - bad.ml:5:0: Global mutable state 'global_cache' of type 'array' detected - instead of accessing a global ref, consider creating an init value and passing it through function parameters
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E351 good.ml
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
