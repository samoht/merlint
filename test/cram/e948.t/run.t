Bad: a protocol state module using anti-pattern verbs (send, parse_*).
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E948 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E948] Protocol verb vocabulary (2 issues)
    A state-machine module uses the canonical verb vocabulary (v, client, server,
    handle, incoming, outgoing, close, timer, next_timeout). The anti-pattern
    synonyms parse_* / process_* / eat_* and bare send / recv / receive / read /
    write / step / make / create / init / shutdown are rejected -- each maps to a
    canonical verb. See E946 for the module, E947 for immutable state, E949 for
    one machine per module.
    - bad/proto/lib/state.ml:4:0: State.send is not a canonical protocol verb. Rename it to outgoing; the state machine uses the canonical vocabulary (v / client / server / handle / incoming / outgoing / close), and the parse_* / process_* / eat_* and bare send / recv / make synonyms are rejected.
    - bad/proto/lib/state.ml:5:0: State.parse_frame is not a canonical protocol verb. Rename it to handle; the state machine uses the canonical vocabulary (v / client / server / handle / incoming / outgoing / close), and the parse_* / process_* / eat_* and bare send / recv / make synonyms are rejected.
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬────────────────────────────────╮
  │ Category           │ Issues                         │
  ├────────────────────┼────────────────────────────────┤
  │ Naming Conventions │ 2 (2 protocol verb vocabulary) │
  ╰────────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E948` for the rule's description, hint, and good/bad examples.
  [1]

Good: a protocol state module using the canonical verb vocabulary.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E948 good/
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
