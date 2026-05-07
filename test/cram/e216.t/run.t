Test bad example - should find invalid_arg with Fmt.str:
  $ merlint -B -r E216 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    [E216] Use Fmt.invalid_arg Instead of invalid_arg (Fmt.str) (4 issues)
    Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...). Fmt.invalid_arg
    provides printf-style formatting directly, making the code more concise and
    readable.
    - bad.ml:3:4: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) - Fmt.invalid_arg provides printf-style formatting directly
    - bad.ml:8:4: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) - Fmt.invalid_arg provides printf-style formatting directly
    - bad.ml:14:4: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) - Fmt.invalid_arg provides printf-style formatting directly
    - bad.ml:20:16: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) - Fmt.invalid_arg provides printf-style formatting directly
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬────────────────────────────────────────────────────────╮
  │ Category   │ Issues                                                 │
  ├────────────┼────────────────────────────────────────────────────────┤
  │ Code Style │ 4 (4 use fmt.invalid_arg instead of invalid_arg        │
  │            │ (fmt.str))                                             │
  ╰────────────┴────────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
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
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
