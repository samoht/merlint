Build fixture project:
  $ dune build @check

Test bad example - should find complexity issues:
  $ merlint -B -r E001 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E001] High Cyclomatic Complexity (1 issue)
    High cyclomatic complexity makes code harder to understand and test. Consider
    breaking complex functions into smaller, more focused functions. Each function
    should ideally do one thing well.
    - bad.ml:1:0: Function 'check_input' has cyclomatic complexity of 7 (threshold: 5)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬──────────────────────────────────╮
  │ Category     │ Issues                           │
  ├──────────────┼──────────────────────────────────┤
  │ Code Quality │ 1 (1 high cyclomatic complexity) │
  ╰──────────────┴──────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E001` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint -B -r E001 good.ml
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

Test large flat pattern match - breadth alone is not complexity:
  $ merlint -B -r E001 flat_match.ml
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

Test OCaml syntax that should stay below the complexity threshold:
  $ merlint -B -r E001 syntax_good.ml
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

Test OCaml syntax with nested decisions:
  $ merlint -B -r E001 syntax_bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (2 total issues)
    [E001] High Cyclomatic Complexity (2 issues)
    High cyclomatic complexity makes code harder to understand and test. Consider
    breaking complex functions into smaller, more focused functions. Each function
    should ideally do one thing well.
    - syntax_bad.ml:1:0: Function 'branchy' has cyclomatic complexity of 7 (threshold: 5)
    - syntax_bad.ml:12:0: Function 'guarded' has cyclomatic complexity of 6 (threshold: 5)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬──────────────────────────────────╮
  │ Category     │ Issues                           │
  ├──────────────┼──────────────────────────────────┤
  │ Code Quality │ 2 (2 high cyclomatic complexity) │
  ╰──────────────┴──────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E001` for the rule's description, hint, and good/bad examples.
  [1]
