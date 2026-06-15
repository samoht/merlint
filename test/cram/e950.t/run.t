Bad: a protocol state module that raises (failwith) on bad input.
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E950 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E950] Total protocol transitions (2 issues)
    A protocol's state machine is total: it returns errors as values, never
    raises. In a state-machine module, reject bad input with an Error rather than
    raise / failwith / invalid_arg. See E946-E949 for the rest of the protocol
    shape.
    - bad/proto/lib/state.ml:6:13: State is not total: it raises via failwith. A protocol transition rejects bad input by returning an Error value; make a genuinely unreachable case unreachable in the type rather than asserting.
    - bad/proto/lib/state.ml:7:21: State is not total: it raises via assert. A protocol transition rejects bad input by returning an Error value; make a genuinely unreachable case unreachable in the type rather than asserting.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────────────╮
  │ Category          │ Issues                           │
  ├───────────────────┼──────────────────────────────────┤
  │ Project Structure │ 2 (2 total protocol transitions) │
  ╰───────────────────┴──────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E950` for the rule's description, hint, and good/bad examples.
  [1]

Good: a protocol state module that returns a result on bad input.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E950 good/
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
