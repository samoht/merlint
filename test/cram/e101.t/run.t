Test bad example - should find every use of Marshal:
  $ dune build @check
  $ merlint --build -r E101 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (4 total issues)
    [E101] No Marshal usage (4 issues)
    The Marshal module (and output_value/input_value) serializes values without
    their type. A marshalled value carries no type information, so Marshal.from_*
    can be read back at any type - including an abstract type - forging values
    that violate the invariants their module guarantees. Deserializing
    attacker-controlled data this way is also a code-execution risk. Use a typed
    codec (a wire or cbor encoder and decoder, or a hand-written printer and
    parser) instead. If a trusted in-process boundary truly needs it, isolate it
    in one module and document why.
    - bad.ml:1:13: Usage of Marshal.to_string detected - untyped (de)serialization bypasses the type system
    - bad.ml:2:19: Usage of Marshal.from_string detected - untyped (de)serialization bypasses the type system
    - bad.ml:3:16: Usage of output_value detected - untyped (de)serialization bypasses the type system
    - bad.ml:4:23: Usage of input_value detected - untyped (de)serialization bypasses the type system
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────╮
  │ Category     │ Issues                 │
  ├──────────────┼────────────────────────┤
  │ Code Quality │ 4 (4 no marshal usage) │
  ╰──────────────┴────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E101` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E101 good.ml
  Dune root: $TESTCASE_ROOT/
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
