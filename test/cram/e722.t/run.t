
Test bad example - fuzz stanza using (test ...) instead of (executable ...):
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E722 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (1 total issues)
    [E722] Fuzz Uses Test Stanza (1 issue)
    Fuzz targets should use (executable ...) stanzas with explicit (rule (alias
    runtest) ...) and (rule (alias fuzz) ...) rules, not (test ...) stanzas. This
    enables property-based testing during dune test and separate AFL campaign
    workflows.
    - bad/fuzz/dune:1:0: Fuzz stanza 'fuzz_parser' uses (test ...) - use (executable ...) with (rule (alias runtest) ...) instead
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬─────────────────────────────╮
  │ Category     │ Issues                      │
  ├──────────────┼─────────────────────────────┤
  │ Test Quality │ 1 (1 fuzz uses test stanza) │
  ╰──────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E722` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - fuzz stanza using (executable ...):
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E722 good/
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
