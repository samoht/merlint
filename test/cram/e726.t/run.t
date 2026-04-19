Test bad example - empty fuzz suites:
  $ merlint -B -r E726 bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E726] Empty Fuzz Suite (2 issues)
    An empty fuzz suite provides no coverage. Fuzz tests should: (1) test crash
    safety of all parsers and decoders on arbitrary input, (2) verify roundtrip
    invariants (decode(encode(x)) = x), (3) exercise state machine transitions
    including invalid ones, (4) cover boundary conditions and edge cases that unit
    tests miss. A suite with no test cases will never find bugs.
    - bad/fuzz_encoder.ml:3:0: Fuzz suite 'encoder' is empty — add meaningful fuzz tests covering parsers, encoders, state machines, and edge cases
    - bad/fuzz_parser.ml:1:0: Fuzz suite 'parser' is empty — add meaningful fuzz tests covering parsers, encoders, state machines, and edge cases
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬────────────────────────╮
  │ Category     │ Issues                 │
  ├──────────────┼────────────────────────┤
  │ Test Quality │ 2 (2 empty fuzz suite) │
  ╰──────────────┴────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - non-empty fuzz suite:
  $ merlint -B -r E726 good/
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
