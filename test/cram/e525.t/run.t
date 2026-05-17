Test bad example - foo/ has .opam but no foo/dune with %{dune-warnings}:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E525 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E525] Package root dune missing %{dune-warnings} (1 issue)
    Create <package>/dune containing (env (dev (flags :standard
    %{dune-warnings}))), and bump <package>/dune-project to (lang dune 3.21) or
    newer. This mirrors the workspace-root dune so that a standalone opam build of
    the package still enforces strict warnings under the dev profile. Reference:
    alcobar/dune.
    - bad/foo/dune:1:0: foo has no root dune file; add foo/dune with (env (dev (flags :standard %{dune-warnings}))) so standalone opam builds fail on warnings
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────────────────────────────╮
  │ Category          │ Issues                                           │
  ├───────────────────┼──────────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 package root dune missing %{dune-warnings}) │
  ╰───────────────────┴──────────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E525` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - foo/ has dune enabling %{dune-warnings} and modern dune-project:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E525 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 0 files
  
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
