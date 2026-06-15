Bad: a protocol-tagged package with no Protocol / Client / Server module.
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E946 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E946] Protocol state machine (1 issue)
    A protocol package (tagged protocol) is a codec plus an I/O-free state
    machine. Expose that state machine as a Protocol module, or Client / Server
    for asymmetric protocols. Purity of the core is E930; AST/codec layering is
    E945.
    - bad/proto/proto.opam:1:0: proto is tagged protocol but exposes no state-machine module. A protocol is a codec plus an I/O-free state machine; put it in a Protocol module (or Client / Server for asymmetric protocols).
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────────╮
  │ Category          │ Issues                       │
  ├───────────────────┼──────────────────────────────┤
  │ Project Structure │ 1 (1 protocol state machine) │
  ╰───────────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E946` for the rule's description, hint, and good/bad examples.
  [1]

Good: a protocol-tagged package exposing a Protocol state-machine module.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E946 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 2 files
  
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
