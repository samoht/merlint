Test bad example - package missing README.md and LICENSE.md:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E913 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E913] Missing package metadata (1 issue)
    Add the human-facing metadata files every opam package ships at its source
    root: a README.md describing the package and a license file (LICENSE.md).
    These travel with the package when it is split out to its own repository.
    - bad/pkg/dune-project:1:0: pkg: missing README.md, LICENSE.md
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────╮
  │ Category          │ Issues                         │
  ├───────────────────┼────────────────────────────────┤
  │ Project Structure │ 1 (1 missing package metadata) │
  ╰───────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E913` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - package with README.md and LICENSE.md:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E913 good/
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
