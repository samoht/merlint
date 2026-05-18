Test bad example - dune missing regen-traces alias:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E810 bad/
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
    [E810] Missing regen-traces alias (1 issue)
    Every interop test dune file must define a regen-traces alias as the single
    trigger for refreshing traces: `(rule (alias regen-traces) ...)`.
    - bad/foo/test/interop/oracle/dune:1:0: Interop test bad/foo/test/interop/oracle/dune missing regen-traces alias
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬──────────────────────────────────╮
  │ Category        │ Issues                           │
  ├─────────────────┼──────────────────────────────────┤
  │ Interop Testing │ 1 (1 missing regen-traces alias) │
  ╰─────────────────┴──────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E810` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - dune defines regen-traces alias:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E810 good/
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
