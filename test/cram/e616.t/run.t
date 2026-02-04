Test bad example - should find fail (Fmt.str) patterns:
  $ merlint -r E616 test_bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (4 total issues)
    [E616] Use failf Instead of fail (Fmt.str) (4 issues)
    In test files, use Alcotest.failf or failf instead of Alcotest.fail (Fmt.str
    ...) or fail (Fmt.str ...). The failf function provides printf-style
    formatting directly, making the code more concise and readable.
    - test_bad.ml:5:0: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:11:0: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:18:0: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
    - test_bad.ml:23:0: Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf provides printf-style formatting directly
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E616 test_good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
