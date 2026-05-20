Package-less fuzz aliases in a multi-package project are not attributable.
E727 requires an explicit [(package ...)] field on the runtest and fuzz rules.

  $ merlint -r E727 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E727] Package-less fuzz runner (1 issue)
    In a multi-package dune project, the rules that attach a private fuzz runner
    to the runtest and fuzz aliases must say which package owns them with
    [(package PKG)]. The executable stays private; put the package field on the
    [(rule (alias runtest) ...)] and [(rule (alias fuzz) ...)] stanzas.
    - bad/fuzz/dune:1:0: bad/fuzz/dune is in a multi-package project (pkg-a, pkg-b) and has package-less fuzz aliases (@fuzz, @runtest). Add [(package PKG)] to the corresponding [(rule (alias ...))] stanzas so project-index can attribute the fuzz test scope without guessing.
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────╮
  │ Category     │ Issues                         │
  ├──────────────┼────────────────────────────────┤
  │ Test Quality │ 1 (1 package-less fuzz runner) │
  ╰──────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E727` for the rule's description, hint, and good/bad examples.
  [1]

  $ merlint -r E727 good/
  Dune root: $TESTCASE_ROOT/good/
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
