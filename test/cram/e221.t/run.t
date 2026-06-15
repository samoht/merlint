Bad: a file in a subtree whose merlint.toml bans Printf/Format/Fmt still uses them.
  $ dune build @check
  $ merlint --build -r E221 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    [E221] Disallowed module (4 issues)
    This file references a module banned by the [disallowed_modules] list in a
    merlint.toml that covers it. Use an allowed alternative, or relax the ban for
    this subtree. The ban is empty by default and scoped to the directory tree of
    the merlint.toml that declares it, so a subtree that must not depend on
    Printf/Format/Fmt can forbid them without affecting the rest of the project.
    - bad.ml:1:26: Stdlib.Printf.sprintf is disallowed here: module Stdlib.Printf is banned by disallowed_modules in merlint.toml.
    - bad.ml:2:20: Stdlib.Printf.printf is disallowed here: module Stdlib.Printf is banned by disallowed_modules in merlint.toml.
    - bad.ml:3:21: Stdlib.Format.asprintf is disallowed here: module Stdlib.Format is banned by disallowed_modules in merlint.toml.
    - bad.ml:4:17: Fmt.str is disallowed here: module Fmt is banned by disallowed_modules in merlint.toml.
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬─────────────────────────╮
  │ Category   │ Issues                  │
  ├────────────┼─────────────────────────┤
  │ Code Style │ 4 (4 disallowed module) │
  ╰────────────┴─────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E221` for the rule's description, hint, and good/bad examples.
  [1]

Good: the same subtree, formatting without the banned modules.
  $ merlint --build -r E221 good.ml
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

Shadow: a local Printf/Format does not resolve to Stdlib, so it is not banned.
  $ merlint --build -r E221 shadow.ml
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
