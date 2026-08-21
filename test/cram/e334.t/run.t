Build fixture project:
  $ dune build @check

Test bad example - variants and records whose every case shares a prefix.
Token_eof is exempted via allowed_words; its sibling Token_word is still
flagged:
  $ merlint --build -r E334 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (8 total issues)
    [E334] Redundant Variant/Field Prefixes (8 issues)
    When every constructor of a variant, or every field of a record, starts with
    the same prefix, that prefix is redundant: the type already names the concept
    and OCaml's type-directed disambiguation resolves the bare name at call sites.
    Drop the shared prefix (type foo = Bar | Baz, not Foo_bar | Foo_baz; { bar;
    baz }, not { foo_bar; foo_baz }). When a bare field would be an OCaml keyword
    the convention is a trailing underscore (entity_type -> type_). Keep a prefix
    only when a bare case would be a spec-mandated name listed in allowed_words.
    - bad.ml:5:2: Constructor 'Status_pending' shares redundant prefix 'Status_' with all constructors of type 'status' - consider 'Pending' (type disambiguation handles the rest at call sites)
    - bad.ml:6:2: Constructor 'Status_running' shares redundant prefix 'Status_' with all constructors of type 'status' - consider 'Running' (type disambiguation handles the rest at call sites)
    - bad.ml:7:2: Constructor 'Status_done' shares redundant prefix 'Status_' with all constructors of type 'status' - consider 'Done' (type disambiguation handles the rest at call sites)
    - bad.ml:10:15: Field 'point_x' shares redundant prefix 'point_' with all fields of type 'point' - consider 'x' (type disambiguation handles the rest at call sites)
    - bad.ml:10:30: Field 'point_y' shares redundant prefix 'point_' with all fields of type 'point' - consider 'y' (type disambiguation handles the rest at call sites)
    - bad.ml:14:2: Constructor 'Token_word' shares redundant prefix 'Token_' with all constructors of type 'token' - consider 'Word' (type disambiguation handles the rest at call sites)
    - bad.ml:19:16: Field 'entity_id' shares redundant prefix 'entity_' with all fields of type 'entity' - consider 'id' (type disambiguation handles the rest at call sites)
    - bad.ml:19:33: Field 'entity_type' shares redundant prefix 'entity_' with all fields of type 'entity' - consider 'type_' (type disambiguation handles the rest at call sites)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬────────────────────────────────────────╮
  │ Category           │ Issues                                 │
  ├────────────────────┼────────────────────────────────────────┤
  │ Naming Conventions │ 8 (8 redundant variant/field prefixes) │
  ╰────────────────────┴────────────────────────────────────────╯
  
  
  Summary: ✗ 8 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E334` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E334 good.ml
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

A declaration is in the parsetree: its name, its kind and where it is are read
from the source itself, so answering this rule needs nothing the compiler ever
wrote. Record the answer with the artefacts present, take every one of them
away, and the answer does not move -- not the findings and not the verdict,
which would report the run incomplete if a rule had wanted a typedtree:

  $ merlint --build -r E334 bad.ml > built.txt
  [1]
  $ merlint --build -r E334 good.ml > built-good.txt
  $ rm -rf _build
  $ find . -name '*.cmt*'
  $ merlint -r E334 bad.ml > unbuilt.txt
  [1]
  $ merlint -r E334 good.ml > unbuilt-good.txt
  $ diff built.txt unbuilt.txt
  $ diff built-good.txt unbuilt-good.txt
