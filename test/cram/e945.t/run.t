Bad: value.ml depends on its sibling Codec, inverting the encoding layering.
  $ (cd bad && dune build @check)
  $ merlint --build -r E945 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E945] Encoding layering (1 issue)
    The ocaml-encodings layering is one-way codec -> value: codec.ml holds [type
    value = Value.t]; value.ml is the base layer and must not depend on Codec.
    Dependency order only -- a separate parser engine is fine.
    - bad/lib/value.ml:1:0: value.ml depends on Codec, inverting the codec -> value layering. Keep value.ml the base layer and move parse entry points out of it.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────╮
  │ Category          │ Issues                  │
  ├───────────────────┼─────────────────────────┤
  │ Project Structure │ 1 (1 encoding layering) │
  ╰───────────────────┴─────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E945` for the rule's description, hint, and good/bad examples.
  [1]

Good: value.ml is the base layer; codec.ml depends on Value (codec -> value).
  $ (cd good && dune build @check)
  $ merlint --build -r E945 good/
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
