Build fixture project:
  $ dune build @check

Test bad example - should flag a printer not named pp / pp_<type>:
  $ merlint --build -r E336 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E336] Pretty-printer naming (1 issue)
    Pretty-printers — values of type [_ Fmt.t] or [Format.formatter -> _ -> unit]
    — follow a fixed naming convention: [pp] when the value type is the module's
    main type [t], and [pp_<type>] otherwise. The convention matches
    [Fmt.pp_print_*] and [Format.pp_print_*] in the stdlib.
    - bad.mli:3:0: Pretty-printer 'print' should be named 'pp' (functions of type [_ Fmt.t] or [Format.formatter -> _ -> unit] use the [pp]/[pp_<type>] convention)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬─────────────────────────────╮
  │ Category           │ Issues                      │
  ├────────────────────┼─────────────────────────────┤
  │ Naming Conventions │ 1 (1 pretty-printer naming) │
  ╰────────────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E336` for the rule's description, hint, and good/bad examples.
  [1]



Test good example - should find no issues:
  $ merlint --build -r E336 good.ml
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
