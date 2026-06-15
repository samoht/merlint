Bad: a protocol state module with a mutable field and a bytes field.
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E947 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (2 total issues)
    [E947] Immutable protocol state (2 issues)
    A protocol's state machine is a pure value, so its state type carries no
    mutable field and no bytes / ref / array. Mutable scratch (decrypt ring,
    reused buffer, dynamic table) is passed in as a borrowed ~rx argument or lives
    in the I/O adapter, never in the state. See E946 for the state-machine module,
    E948 for verb names, E949 for one machine per module.
    - bad/proto/lib/state.ml:1:0: State.payload has type bytes in the protocol state. bytes is a mutable buffer; the immutable state keeps payloads as string and pushes mutable scratch to the I/O adapter (or a borrowed ~rx argument).
    - bad/proto/lib/state.ml:1:0: State.seen is a mutable field of the protocol state. Protocol state is immutable; pass mutable scratch in as a borrowed ~rx argument or keep it in the I/O adapter, never as a field of the state.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────╮
  │ Category          │ Issues                         │
  ├───────────────────┼────────────────────────────────┤
  │ Project Structure │ 2 (2 immutable protocol state) │
  ╰───────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E947` for the rule's description, hint, and good/bad examples.
  [1]

Good: a protocol state module with an immutable, buffer-free state.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E947 good/
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
