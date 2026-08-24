Build fixture project:
  $ dune build @check

Test bad example - should find catch-all exception handler:
  $ merlint --build -r E105 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E105] Catch-all Exception Handler (1 issue)
    Catch-all exception handlers (with _ ->) can hide unexpected errors and make
    debugging difficult. Always handle specific exceptions explicitly. If you must
    catch all exceptions, log them or re-raise after cleanup.
    - bad.ml:1:29: Catch-all exception handler found. This can hide unexpected errors.
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬───────────────────────────────────╮
  │ Category     │ Issues                            │
  ├──────────────┼───────────────────────────────────┤
  │ Code Quality │ 1 (1 catch-all exception handler) │
  ╰──────────────┴───────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E105` for the rule's description, hint, and good/bad examples.
  [1]

Test JSON report - should encode the scan report, not only logs:
  $ merlint --build --json -r E105 bad.ml
  {"project_root":"$TESTCASE_ROOT/","files_analyzed":1,"rules_applied":1,"total_issues":1,"unchecked":0,"unchecked_files":[],"unclaimed_files":[],"passed":false,"issues":[{"code":"E105","title":"Catch-all Exception Handler","category":"Code Quality","message":"Catch-all exception handler found. This can hide unexpected errors.","location":{"file":"bad.ml","start":{"line":1,"column":29},"end":{"line":1,"column":30}}}],"excluded":[]}
  [1]

Test good example - should find no issues:
  $ merlint --build -r E105 good.ml
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
