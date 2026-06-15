Bad: a protocol transition (handle) returning unit.
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E952 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E952] Result-returning transitions (1 issue)
    A protocol transition (handle / incoming / outgoing / close / timer) returns a
    result carrying the new state, output, events, and an Error on bad input --
    never unit, which forces in-place mutation and raising. See E947 (immutable
    state) and E950 (total transitions) for the related invariants.
    - bad/proto/lib/state.ml:4:0: State.handle returns unit. A protocol transition returns its outcome as a value -- a new state, the bytes to send, the events, and an Error on bad input -- so it returns a result, never unit (which forces mutation and raising).
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────────╮
  │ Category          │ Issues                             │
  ├───────────────────┼────────────────────────────────────┤
  │ Project Structure │ 1 (1 result-returning transitions) │
  ╰───────────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E952` for the rule's description, hint, and good/bad examples.
  [1]

Good: a protocol transition returning a result.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E952 good/
  Dune root: $TESTCASE_ROOT/good/
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
