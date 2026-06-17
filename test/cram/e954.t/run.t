Bad: a protocol state module with a constructor but no incoming verb.
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E954 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E954] Protocol state machine entry points (1 issue)
    A protocol's state machine exposes both an inbound verb (incoming) and a
    constructor (v, or a role constructor: client / server / sender / receiver /
    initiator / responder / requester), so a reviewer can always find where the
    machine is built and where it steps. See E946 for the module being present,
    E948 for the verb names, E950 for total transitions.
    - bad/proto/lib/state.ml:1:0: State exposes no `incoming` verb. A protocol state machine's inbound transition is named incoming (t -> input -> ...); add it so the machine's entry point is findable.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬───────────────────────────────────────────╮
  │ Category          │ Issues                                    │
  ├───────────────────┼───────────────────────────────────────────┤
  │ Project Structure │ 1 (1 protocol state machine entry points) │
  ╰───────────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E954` for the rule's description, hint, and good/bad examples.
  [1]

Good: a protocol state module exposing v and incoming.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E954 good/
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
