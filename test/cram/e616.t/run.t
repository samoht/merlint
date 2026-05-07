Test bad example - should find fail (Fmt.str) patterns:
  $ merlint -B -r E616 test_bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (5 total issues)
    [E616] Use failf Instead of fail (Fmt.str) (5 issues)
    In test files, use Alcotest.failf or failf instead of Alcotest.fail (Fmt.str
    ...) or fail (Fmt.str ...). The failf function provides printf-style
    formatting directly, making the code more concise and readable.
    - test_bad.ml:5:10: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:11:12: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:18:10: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:23:10: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:29:4: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬───────────────────────────────────────────╮
  │ Category     │ Issues                                    │
  ├──────────────┼───────────────────────────────────────────┤
  │ Test Quality │ 5 (5 use failf instead of fail (fmt.str)) │
  ╰──────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 5 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E616 test_good.ml
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
