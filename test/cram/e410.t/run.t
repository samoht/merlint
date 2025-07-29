Test bad example - should find bad documentation style:
  $ merlint -r E410 bad.mli
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (3 total issues)
    [E410] Bad Documentation Style (3 issues)
    Follow OCaml documentation conventions: Functions should use '[name args]
    description.' format. Operators should use infix notation like '[x op y]
    description.' All documentation should end with a period. Avoid redundant
    phrases like 'This function...'.
    - bad.mli:3:0: Documentation for 'parse' use doc comment (** ... *) instead of regular comment (* ... *)
    - bad.mli:7:0: Documentation for '@>' should use '[x op y] description.' format for operators
    - bad.mli:10:0: Documentation for '<@' should end with a period, should use '[x op y] description.' format for operators
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E410 good.mli
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
