Build fixture project:
  $ dune build @check

Bad: code spans naming exported API items should be odoc links.
  $ merlint --build -r E420 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (9 total issues)
    [E420] Missing Odoc Cross-Reference Link (9 issues)
    When documentation mentions another exported API item, use an odoc
    cross-reference link such as {!type-t}, {!val-v}, {!module-M},
    {!module-type-S}, {!exception-E}, {!constructor-C}, {!field-f}, {!class-c}, or
    {!class-type-c}. Keep [x] for code literals and documented arguments.
    - bad.mli:15:0: Documentation for 'M' mentions exported module type [S]; use odoc link {!module-type-S}
    - bad.mli:28:0: Documentation for 'make' mentions exported class type [ct]; use odoc link {!class-type-ct}
    - bad.mli:28:0: Documentation for 'make' mentions exported class [c]; use odoc link {!class-c}
    - bad.mli:28:0: Documentation for 'make' mentions exported exception [E]; use odoc link {!exception-E}
    - bad.mli:28:0: Documentation for 'make' mentions exported module type [S]; use odoc link {!module-type-S}
    - bad.mli:28:0: Documentation for 'make' mentions exported module [M]; use odoc link {!module-M}
    - bad.mli:28:0: Documentation for 'make' mentions exported constructor [Fast]; use odoc link {!constructor-Fast}
    - bad.mli:28:0: Documentation for 'make' mentions exported field [value]; use odoc link {!field-value}
    - bad.mli:28:0: Documentation for 'make' mentions exported type [t]; use odoc link {!type-t}
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬─────────────────────────────────────────╮
  │ Category      │ Issues                                  │
  ├───────────────┼─────────────────────────────────────────┤
  │ Documentation │ 9 (9 missing odoc cross-reference link) │
  ╰───────────────┴─────────────────────────────────────────╯
  
  
  Summary: ✗ 9 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E420` for the rule's description, hint, and good/bad examples.
  [1]

Good: odoc links satisfy the cross-reference rule.
  $ merlint --build -r E420 good.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
