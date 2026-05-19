Test bad example - generate.py defines its own encode function:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E830 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E830] Inlined algorithm in generator (1 issue)
    The generator MUST call the upstream tool's public API. Never reimplement the
    algorithm being verified — this defeats the purpose of interop testing. If
    the public API doesn't expose what you need, drop the test rather than
    inlining.
    - (global) Interop generator bad/foo/test/interop/oracle/scripts/generate.py: defines encode/decode/compute functions — may be reimplementing the algorithm instead of calling the oracle's API
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬──────────────────────────────────────╮
  │ Category        │ Issues                               │
  ├─────────────────┼──────────────────────────────────────┤
  │ Interop Testing │ 1 (1 inlined algorithm in generator) │
  ╰─────────────────┴──────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E830` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - generate.py only calls the upstream library:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E830 good/
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
