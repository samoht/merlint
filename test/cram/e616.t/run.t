Build fixture project:
  $ dune build @check

Test bad example - should find fail (Fmt.str) patterns:
  $ merlint -B -r E616 test_bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (6 total issues)
    [E616] Use failf Instead of fail (Fmt.str) (6 issues)
    In test files, use Alcotest.failf or failf instead of Alcotest.fail (Fmt.str
    ...) or fail (Fmt.str ...). The failf function provides printf-style
    formatting directly, making the code more concise and readable.
    - test_bad.ml:10:10: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:16:12: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:23:10: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:28:10: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:34:4: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:40:10: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬───────────────────────────────────────────╮
  │ Category     │ Issues                                    │
  ├──────────────┼───────────────────────────────────────────┤
  │ Test Quality │ 6 (6 use failf instead of fail (fmt.str)) │
  ╰──────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 6 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E616` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E616 test_good.ml
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
