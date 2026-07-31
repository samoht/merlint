Build fixture project:
  $ dune build @check

Test bad example - should find missing log source:
  $ merlint --build -r E510 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E510] Missing Log Source (1 issue)
    Modules that use logging should declare a log source for better debugging and
    log filtering. Add 'let src = Logs.Src.create "module.name" ~doc:"..."'
    - bad.ml:1:0: Module 'Bad' uses logging but has no log source defined
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────╮
  │ Category          │ Issues                   │
  ├───────────────────┼──────────────────────────┤
  │ Project Structure │ 1 (1 missing log source) │
  ╰───────────────────┴──────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E510` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E510 good.ml
  Dune root: $TESTCASE_ROOT/
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

A test module emits through a reporter in order to assert on what it emitted,
so the rule's own remedy -- declare a source -- would change the record under
assertion. Test files are left alone:

  $ merlint --build -r E510 test/test_reporter.ml
  Dune root: $TESTCASE_ROOT/
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
