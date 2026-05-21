Package-less MDX stanzas in a multi-package project are not attributable. E922
requires an explicit [(package ...)] field on each [(mdx ...)] stanza.

  $ merlint -r E922 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (1 total issues)
    [E922] Package-less MDX stanza (1 issue)
    In a multi-package dune project, MDX stanzas must say which package owns the
    documentation check with [(package PKG)]. Dune attaches MDX to runtest
    automatically; the package field is for ownership and package-filtering, not
    alias plumbing.
    - bad/doc/dune:1:0: bad/doc/dune is in a multi-package project (pkg-a, pkg-b) and has package-less MDX stanzas covering README.md, guide.mld. Add [(package PKG)] to each [(mdx ...)] stanza so project-index can attribute documentation checks without guessing.
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬───────────────────────────────╮
  │ Category      │ Issues                        │
  ├───────────────┼───────────────────────────────┤
  │ Documentation │ 1 (1 package-less mdx stanza) │
  ╰───────────────┴───────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E922` for the rule's description, hint, and good/bad examples.
  [1]

  $ merlint -r E922 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
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
