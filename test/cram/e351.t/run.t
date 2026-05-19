Test bad example - should find exposed global mutable state in interface:
  $ dune build @check
  $ merlint --build -r E351 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (2 total issues)
    [E351] Exposed Global Mutable State (2 issues)
    Exposing global mutable state in interfaces (.mli files) breaks encapsulation
    and makes programs harder to reason about. Instead of exposing refs or mutable
    arrays directly, provide functions that encapsulate state manipulation. This
    preserves module abstraction and makes the API clearer. Internal mutable state
    in .ml files is fine as long as it's not exposed in the interface.
    - bad.mli:1:0: Exposed global mutable state 'counter' of type 'ref' in interface - instead of exposing mutable state, consider providing functions that encapsulate the state manipulation
    - bad.mli:2:0: Exposed global mutable state 'global_cache' of type 'array' in interface - instead of exposing mutable state, consider providing functions that encapsulate the state manipulation
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────────╮
  │ Category     │ Issues                             │
  ├──────────────┼────────────────────────────────────┤
  │ Code Quality │ 2 (2 exposed global mutable state) │
  ╰──────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E351` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues (properly encapsulated state):
  $ merlint --build -r E351 good.mli
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

Test shadow example - local ref/array aliases are not Stdlib types:
  $ merlint --build -r E351 shadow.mli
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
