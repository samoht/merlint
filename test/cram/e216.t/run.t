Test bad example - should find invalid_arg with Fmt.str:
  $ merlint -B -r E216 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (2 total issues)
    [E216] Use Fmt.invalid_arg Instead of invalid_arg (Fmt.str) (2 issues)
    Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...). Fmt.invalid_arg
    provides printf-style formatting directly, making the code more concise and
    readable.
    - bad.ml:3:0: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) - Fmt.invalid_arg provides printf-style formatting directly
    - bad.ml:8:0: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) - Fmt.invalid_arg provides printf-style formatting directly
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  ╭────────────┬────────────────────────────────────────────────────────╮
  │ Category   │ Issues                                                 │
  ├────────────┼────────────────────────────────────────────────────────┤
  │ Code Style │ 2 (2 use fmt.invalid_arg instead of invalid_arg (fmt.… │
  ╰────────────┴────────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E216 good.ml
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
