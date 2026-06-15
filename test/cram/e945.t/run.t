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
    [E945] AST/codec layering (1 issue)
    One layering for codecs and protocols: the AST (Value for data, Message for a
    protocol) is the base, and the typed Codec depends on it -- never the reverse.
    An AST module that references its sibling Codec inverts the order. A protocol
    is a codec plus a state machine, so message.ml follows the same rule.
    Dependency order only -- which parser the codec uses is unconstrained.
    - bad/lib/value.ml:1:0: the AST (value.ml / message.ml) depends on Codec, inverting the codec -> AST layering. The typed Codec depends on the AST, not the reverse; keep the AST a plain data type and move parse entry points out of it.
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────╮
  │ Category          │ Issues                   │
  ├───────────────────┼──────────────────────────┤
  │ Project Structure │ 1 (1 ast/codec layering) │
  ╰───────────────────┴──────────────────────────╯
  
  
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
