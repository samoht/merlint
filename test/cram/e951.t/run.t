Bad: a protocol state module whose message match silently accepts an
unexpected message via a wildcard arm that returns a normal value.
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E951 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E951] Exhaustive message match (1 issue)
    A match over the protocol message type must not use a catch-all wildcard arm
    (| _ -> ...): it defeats the compiler's exhaustiveness check, so a new message
    constructor silently falls through instead of forcing a review. Enumerate
    every constructor (group them to share a rejection). See E946-E950 and E952
    for the rest of the protocol shape.
    - bad/proto/lib/state.ml:2:32: State matches on the message type with a catch-all wildcard arm. The wildcard defeats the compiler's exhaustiveness check -- a message constructor added later silently falls through it. Enumerate every constructor (group them to share a rejection) so the type-checker flags every match when the message type grows.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────╮
  │ Category          │ Issues                         │
  ├───────────────────┼────────────────────────────────┤
  │ Project Structure │ 1 (1 exhaustive message match) │
  ╰───────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E951` for the rule's description, hint, and good/bad examples.
  [1]

Good: a protocol state module that rejects an unexpected message (Error)
and a fully exhaustive match with no wildcard.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E951 good/
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
