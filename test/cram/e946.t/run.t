Bad: codec.ml depends on its sibling Message, inverting the protocol layering.
  $ (cd bad && dune build @check)
  $ merlint --build -r E946 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E946] Protocol layering (1 issue)
    The ocaml-protocols layering is one-way codec <- message: codec.ml is the
    AST-free combinator base and message.ml builds its codecs from it. A codec.ml
    that references its sibling Message inverts that order. Mirror of E945
    (encodings, value is the base). Dependency order only.
    - bad/lib/codec.ml:1:0: codec.ml depends on Message, inverting the codec <- message layering. Keep codec.ml the AST-free base and build the message codecs in message.ml.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────╮
  │ Category          │ Issues                  │
  ├───────────────────┼─────────────────────────┤
  │ Project Structure │ 1 (1 protocol layering) │
  ╰───────────────────┴─────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E946` for the rule's description, hint, and good/bad examples.
  [1]

Good: codec.ml is the AST-free base; message.ml depends on Codec (codec <- message).
  $ (cd good && dune build @check)
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
