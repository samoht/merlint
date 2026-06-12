Test bad example - should find every use of the Obj module:
  $ dune build @check
  $ merlint --build -r E100 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (5 total issues)
    [E100] No Obj usage (5 issues)
    The Obj module bypasses OCaml's type system and is not part of the language.
    Any use (Obj.magic, Obj.repr, Obj.obj, Obj.tag, ...) can cause segmentation
    faults, data corruption, and unpredictable behavior. Use proper type
    definitions, GADTs, or polymorphic variants instead. If an unsafe boundary is
    truly unavoidable, isolate it in one module and document why.
    - bad.ml:1:15: Usage of Obj.magic detected - this is extremely unsafe
    - bad.ml:2:15: Usage of Obj.repr detected - this is extremely unsafe
    - bad.ml:3:24: Usage of Obj.obj detected - this is extremely unsafe
    - bad.ml:4:15: Usage of Obj.tag detected - this is extremely unsafe
    - bad.ml:4:24: Usage of Obj.repr detected - this is extremely unsafe
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────╮
  │ Category     │ Issues             │
  ├──────────────┼────────────────────┤
  │ Code Quality │ 5 (5 no obj usage) │
  ╰──────────────┴────────────────────╯
  
  
  Summary: ✗ 5 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E100` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E100 good.ml
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

Test shadow example - a local Obj module is not Stdlib.Obj:
  $ merlint --build -r E100 shadow.ml
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
