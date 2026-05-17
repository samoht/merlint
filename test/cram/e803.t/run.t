Test bad example - test.ml calls Sys.command:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E803 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E803] Interop test requires external tool (1 issue)
    Interop tests must run from committed traces without needing the external tool
    at test time. The test.ml should only read trace files, never shell out to run
    the oracle. If you need the oracle, put it in the generator script.
    - bad/foo/test/interop/oracle/test.ml:1:16: Interop test bad/foo/test/interop/oracle/test.ml calls Sys.command — test must run from traces alone
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬───────────────────────────────────────────╮
  │ Category        │ Issues                                    │
  ├─────────────────┼───────────────────────────────────────────┤
  │ Interop Testing │ 1 (1 interop test requires external tool) │
  ╰─────────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E803` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - test.ml only reads trace files:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E803 good/
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
