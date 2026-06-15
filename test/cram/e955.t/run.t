Bad: a codec package names a raising variant with a ' suffix instead of _exn.
  $ (cd bad/doc && dune build @check)
  $ merlint --build -r E955 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E955] No prime suffix on values (1 issue)
    A raising variant of a codec entry point is named with the _exn suffix
    (of_string_exn), never a ' suffix (of_string'). The ' suffix is reserved for a
    format-native keyword escape (object', the JSON object sort) or a pp / pp'
    configuration-variant pair; there are no built-in exceptions, so any ' name a
    codec package keeps must be documented in allowed-names in its merlint.toml.
    See E953 for the encoding verb vocabulary.
    - bad/doc/lib/doc.ml:3:0: Doc.decode' uses a ' suffix. A raising variant is named with the _exn suffix, not '; the ' suffix is only for a format-native keyword escape (object') or a pp / pp' configuration-variant pair, and those must be listed in allowed-names in merlint.toml.
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬─────────────────────────────────╮
  │ Category           │ Issues                          │
  ├────────────────────┼─────────────────────────────────┤
  │ Naming Conventions │ 1 (1 no prime suffix on values) │
  ╰────────────────────┴─────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E955` for the rule's description, hint, and good/bad examples.
  [1]

Good: the _exn twin is used; the object' keyword escape is documented in
allowed-names, so it is not flagged.
  $ (cd good/doc && dune build @check)
  $ merlint --build -r E955 good/
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
