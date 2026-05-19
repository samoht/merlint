Test bad example - go script without go.mod:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E806 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E806] Missing go.mod (1 issue)
    Go oracles must pin the upstream module in go.mod with a tagged version or
    pseudo-version. This ensures reproducible trace generation without depending
    on $GOPATH or local clones.
    - bad/foo/test/interop/oracle/scripts/go.mod:1:0: Go oracle bad/foo/test/interop/oracle/scripts/ missing go.mod
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬──────────────────────╮
  │ Category        │ Issues               │
  ├─────────────────┼──────────────────────┤
  │ Interop Testing │ 1 (1 missing go.mod) │
  ╰─────────────────┴──────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E806` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - go script with go.mod:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E806 good/
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
