Test bad example - rust script without Cargo.toml:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E807 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E807] Missing Cargo.toml (1 issue)
    Rust oracles must pin the upstream crate in Cargo.toml with a tagged version
    or git rev. This ensures reproducible trace generation without depending on
    local checkouts.
    - bad/foo/test/interop/oracle/scripts/Cargo.toml:1:0: Rust oracle bad/foo/test/interop/oracle/scripts/ missing Cargo.toml
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬──────────────────────────╮
  │ Category        │ Issues                   │
  ├─────────────────┼──────────────────────────┤
  │ Interop Testing │ 1 (1 missing cargo.toml) │
  ╰─────────────────┴──────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E807` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - rust script with Cargo.toml:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E807 good/
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
