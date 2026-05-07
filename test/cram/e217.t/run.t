Test bad example - should flag generic f (Fmt.str ...) but NOT specialized failwith / invalid_arg cases:
  $ merlint -B -r E217 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (3 total issues)
    [E217] Use Fmt.kstr f Instead of f (Fmt.str) (3 issues)
    Use Fmt.kstr f instead of f (Fmt.str ...). Fmt.kstr is the
    continuation-passing variant of Fmt.str: it formats and hands the resulting
    string to its first argument. The [<fn> (Fmt.str ...)] pattern is dominated by
    [Fmt.kstr <fn> ...] for any single-argument function or constructor.
    Specialized cases ([failwith], [invalid_arg], [Alcotest.fail], [fail]) have
    dedicated helpers — see E215, E216, E616.
    - bad.ml:2:22: Use Fmt.kstr f instead of f (Fmt.str ...) - Fmt.kstr threads the formatted string into the continuation in one step, no intermediate [Fmt.str] needed
    - bad.ml:6:14: Use Fmt.kstr f instead of f (Fmt.str ...) - Fmt.kstr threads the formatted string into the continuation in one step, no intermediate [Fmt.str] needed
    - bad.ml:9:14: Use Fmt.kstr f instead of f (Fmt.str ...) - Fmt.kstr threads the formatted string into the continuation in one step, no intermediate [Fmt.str] needed
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬─────────────────────────────────────────────╮
  │ Category   │ Issues                                      │
  ├────────────┼─────────────────────────────────────────────┤
  │ Code Style │ 3 (3 use fmt.kstr f instead of f (fmt.str)) │
  ╰────────────┴─────────────────────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E217 good.ml
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
