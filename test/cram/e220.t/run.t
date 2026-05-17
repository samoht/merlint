Build fixture project:
  $ dune build @check

Bad interface uses an unconstrained [module type of].

  $ merlint -B -r E220 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (1 total issues)
    [E220] Prefer module alias over unconstrained typeof (1 issue)
    [module X : module type of Y] re-elaborates the target signature and hides
    type equalities behind a fresh abstraction; an alias [module X = Y] is cheaper
    to typecheck and preserves equalities. Keep [module type of] only when you
    immediately narrow with [with type t = ...] / [with module M = ...].
    - bad.mli:1:0: [module Bad : module type of Stdlib.String] without [with type] constraints — replace with [module Bad = Stdlib.String] (cheaper to elaborate, preserves definitional equality).
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬─────────────────────────────────────────────────────╮
  │ Category   │ Issues                                              │
  ├────────────┼─────────────────────────────────────────────────────┤
  │ Code Style │ 1 (1 prefer module alias over unconstrained typeof) │
  ╰────────────┴─────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E220` for the rule's description, hint, and good/bad examples.
  [1]

Alias form is accepted.

  $ merlint -B -r E220 good.mli
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
