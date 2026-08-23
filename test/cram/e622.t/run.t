Package-less test stanzas in a multi-package project are not attributable. E622
requires an explicit [(package ...)] field instead of letting project-index
guess.

  $ merlint -r E622 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E622] Package-less test stanza (1 issue)
    In a multi-package dune project, test stanzas must say which package owns them
    with [(package PKG)]. Without that field, project-index cannot safely
    attribute test modules or test dependency scopes. Add [(package
    <package-name>)] rather than relying on default-package inference.
    - bad/test/dune:1:0: bad/test/dune is in a multi-package project (pkg-a, pkg-b) and has a package-less test stanza. Add [(package PKG)] so project-index can attribute the test scope without guessing.
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────╮
  │ Category     │ Issues                         │
  ├──────────────┼────────────────────────────────┤
  │ Test Quality │ 1 (1 package-less test stanza) │
  ╰──────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E622` for the rule's description, hint, and good/bad examples.
  [1]

  $ merlint -r E622 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 2 files
  
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
