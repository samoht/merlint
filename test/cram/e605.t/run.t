Test bad example - should find missing test files:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint -B -r E605 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 5 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E605] Untested module — write tests for it (2 issues)
    This rule is not a checkbox exercise. The goal is real test coverage and real
    code quality, not a [test_<module>.ml] file that satisfies the linter. Treat
    each untested module as an opportunity: write the tests you'd want a reviewer
    to write before you trusted the code in production. Anchor on the spec when
    one exists -- cite section numbers, copy test vectors verbatim. Probe the edge
    cases the implementation hopes you won't try: empty / single-element /
    maximum-length inputs, NaN, malformed UTF-8, negative sizes, off-by-one
    boundaries, integer overflow. Drive at least one hostile case (random bytes,
    truncated payloads, malicious lengths); the public API should fail with a
    clear error, not crash or corrupt state. Use exact expected values, not loose
    ranges. A trivial module still deserves the exercise -- writing the tests
    usually surfaces the corner the author didn't think through.
    - bad/lib/config.ml:1:0: Module 'config' has no tests yet — write thoughtful, adversarial tests against it. Expected file: bad/test/test_config.ml
    - bad/lib/parser.ml:1:0: Module 'parser' has no tests yet — write thoughtful, adversarial tests against it. Expected file: bad/test/test_parser.ml
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────────────────────────╮
  │ Category     │ Issues                                     │
  ├──────────────┼────────────────────────────────────────────┤
  │ Test Quality │ 2 (2 untested module — write tests for it) │
  ╰──────────────┴────────────────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E605` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues (includes bin/common.ml which is an executable module, not a library, and lib/internal.ml which is a private module):
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint -B -r E605 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 10 files
  
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




Test multidir - analyzing lib and test together should not report missing tests when they exist:
  $ merlint -B -r E605 good/lib good/test
  Dune root: $TESTCASE_ROOT/good
  Running merlint analysis...
  
  Analyzing 8 files
  
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

Test executable modules are not flagged - bin/common.ml should not require a test:
  $ merlint -B -r E605 good/bin/common.ml
  Dune root: $TESTCASE_ROOT/good
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
