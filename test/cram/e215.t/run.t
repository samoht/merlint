Build fixture project:
  $ dune build @check

Test bad example - should find failwith (Fmt.str) patterns:
  $ merlint -B -r E215 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    [E215] Use Fmt.failwith Instead of failwith (Fmt.str) (4 issues)
    Use Fmt.failwith instead of failwith (Fmt.str ...). Fmt.failwith provides
    printf-style formatting directly, making the code more concise and readable.
    - bad.ml:3:4: Use Fmt.failwith instead of failwith (Fmt.str ...) - Fmt.failwith provides printf-style formatting directly
    - bad.ml:10:4: Use Fmt.failwith instead of failwith (Fmt.str ...) - Fmt.failwith provides printf-style formatting directly
    - bad.ml:17:16: Use Fmt.failwith instead of failwith (Fmt.str ...) - Fmt.failwith provides printf-style formatting directly
    - bad.ml:20:16: Use Fmt.failwith instead of failwith (Fmt.str ...) - Fmt.failwith provides printf-style formatting directly
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬──────────────────────────────────────────────────────╮
  │ Category   │ Issues                                               │
  ├────────────┼──────────────────────────────────────────────────────┤
  │ Code Style │ 4 (4 use fmt.failwith instead of failwith (fmt.str)) │
  ╰────────────┴──────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E215` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E215 good.ml
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
