Bad: a codec-tagged package whose top-level module exposes parse / print
instead of the canonical of_string / to_string.
  $ (cd bad/doc && dune build @check)
  $ merlint --build -r E953 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E953] Encoding verb vocabulary (2 issues)
    A data-codec package (tagged codec) exposes its top-level entry points from a
    fixed vocabulary: of_string / to_string / of_reader / to_writer for I/O, and
    decode / encode over the AST, each of_/decode with an _exn twin (never a '
    variant). The bare synonyms parse / from_string / unmarshal / print / unparse
    / marshal / read / input / write / output are rejected -- each maps to a
    canonical verb. The prefixed parse_* / print_* helpers are internal and left
    alone. See E945 for the codec/AST layering, E948 for the protocol verb
    vocabulary.
    - bad/doc/lib/doc.ml:3:0: Doc.parse is not a canonical encoding verb. Rename it to of_string; a codec's top-level entry points are of_string / to_string / of_reader / to_writer (and decode / encode over the AST), and the parse / from_string / print / read / write synonyms are rejected.
    - bad/doc/lib/doc.ml:4:0: Doc.print is not a canonical encoding verb. Rename it to to_string; a codec's top-level entry points are of_string / to_string / of_reader / to_writer (and decode / encode over the AST), and the parse / from_string / print / read / write synonyms are rejected.
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬────────────────────────────────╮
  │ Category           │ Issues                         │
  ├────────────────────┼────────────────────────────────┤
  │ Naming Conventions │ 2 (2 encoding verb vocabulary) │
  ╰────────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E953` for the rule's description, hint, and good/bad examples.
  [1]

Good: a codec-tagged package using the canonical verbs; the prefixed
parse_value helper is internal plumbing and is left alone.
  $ (cd good/doc && dune build @check)
  $ merlint --build -r E953 good/
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
