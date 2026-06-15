Bad: a state module nesting two state machines (Sender, Receiver).
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E949 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E949] One state machine per module (1 issue)
    A state-machine module holds exactly one state-machine type t. Two roles are
    two top-level modules (Client/Server, Sender/Receiver, ...), not nested module
    Sender / module Receiver in one state.ml. See E946 for the module, E947 for
    immutable state, E948 for verb names.
    - bad/proto/lib/state.ml:1:0: state.ml defines 2 state machines (Sender, Receiver); a module holds one state machine. Split each role into its own top-level module (Client/Server, Sender/Receiver, ...), not nested modules in one file.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────────╮
  │ Category          │ Issues                             │
  ├───────────────────┼────────────────────────────────────┤
  │ Project Structure │ 1 (1 one state machine per module) │
  ╰───────────────────┴────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E949` for the rule's description, hint, and good/bad examples.
  [1]

Good: a state module with a single state machine.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E949 good/
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
