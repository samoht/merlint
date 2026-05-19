Test bad example - foo/test/interop/python/ named after language:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E801 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E801] Interop dir named after language (1 issue)
    Interop test directories should be named after the oracle tool (e.g.
    spacepackets, dariol83, crcmod), not the language (e.g. python, go). This
    makes it clear which external implementation is the reference.
    - (global) Interop dir bad/foo/test/interop/python: directory named after language "python", should be named after the oracle tool
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬────────────────────────────────────────╮
  │ Category        │ Issues                                 │
  ├─────────────────┼────────────────────────────────────────┤
  │ Interop Testing │ 1 (1 interop dir named after language) │
  ╰─────────────────┴────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E801` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - foo/test/interop/spacepackets/ named after oracle tool:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E801 good/
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
