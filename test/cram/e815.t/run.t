Test bad example - regen rule runs generate.sh without a REGEN gate:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E815 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E815] Interop regen rule not REGEN-gated (1 issue)
    The rule that regenerates traces must use (mode promote) guarded by
    (enabled_if (= %{env:REGEN=0} 1)), living in traces/dune under (alias regen),
    so a normal `dune test` leaves the traces as committed source and never runs
    the external oracle. Regenerate with `REGEN=1 dune build @regen`.
    - bad/foo/test/interop/oracle/dune:1:0: Interop test bad/foo/test/interop/oracle/dune runs generate.sh without an (enabled_if (= %{env:REGEN=0} 1)) guard
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬──────────────────────────────────────────╮
  │ Category        │ Issues                                   │
  ├─────────────────┼──────────────────────────────────────────┤
  │ Interop Testing │ 1 (1 interop regen rule not regen-gated) │
  ╰─────────────────┴──────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E815` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - regen rule is a REGEN-gated promote rule:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E815 good/
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
