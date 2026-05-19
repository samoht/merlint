Test bad example - foo/dune-project lacks (implicit_transitive_deps false):
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E526 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E526] Package dune-project must disable implicit transitive deps (1 issue)
    Add (implicit_transitive_deps false) to <package>/dune-project (or
    (implicit_transitive_deps false-if-hidden-includes-supported) if you need to
    keep compatibility with OCaml < 5.2). Then audit each (libraries ...) clause
    to list any transitive deps the package actually uses directly. This makes
    (re_export ...) meaningful again and prevents deps from leaking into
    downstream opam depends via META requires.
    - bad/foo/dune-project:1:0: foo/dune-project is missing (implicit_transitive_deps false); transitive deps leak into downstream META requires and pollute consumers' opam depends
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────────────────────────────╮
  │ Category          │ Issues                                                 │
  ├───────────────────┼────────────────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 package dune-project must disable implicit        │
  │                   │ transitive deps)                                       │
  ╰───────────────────┴────────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E526` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - foo/dune-project sets (implicit_transitive_deps false):
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E526 good/
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
