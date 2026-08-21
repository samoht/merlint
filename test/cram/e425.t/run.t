Build fixture project:
  $ dune build @check

Test bad example - a doc comment after the last constructor binds to it:
  $ merlint --build -r E425 bad.mli
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✗ Documentation (2 total issues)
    [E425] Type Documentation Bound to a Constructor (2 issues)
    A variant declaration has no closing delimiter, so a doc comment placed after
    the last constructor attaches to that constructor: odoc renders the type's
    description under one case and the type itself stays undocumented. Put the
    type's documentation before the declaration, on the line above 'type'. If the
    comment really does describe that last constructor, the type is simply
    undocumented: give it its own doc comment before the declaration and the
    constructor's doc becomes unambiguous. Documentation written after the
    declaration is safe for records, aliases and abstract types, which end with a
    delimiter.
    - bad.mli:4:0: Type 'status' has no documentation: the comment after its last constructor documents 'Stopped'. Put the type's doc before 'type status'
    - bad.mli:9:11: Type 'level' has no documentation: the comment after its last constructor documents 'Error'. Put the type's doc before 'type level'
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────┬─────────────────────────────────────────────────╮
  │ Category      │ Issues                                          │
  ├───────────────┼─────────────────────────────────────────────────┤
  │ Documentation │ 2 (2 type documentation bound to a constructor) │
  ╰───────────────┴─────────────────────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E425` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - the type's doc comes before the declaration:
  $ merlint --build -r E425 good.mli
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

Every constructor documented - the trailing comment documents the type:
  $ merlint --build -r E425 every_constructor_good.mli
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

Type documented before the declaration - the last constructor's own doc stays:
  $ merlint --build -r E425 last_constructor_good.mli
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

  $ merlint --build -r E425 bad.mli > built.txt
  [1]
  $ merlint --build -r E425 good.mli > built-good.txt
  $ rm -rf _build
  $ find . -name '*.cmt*'
  $ merlint -r E425 bad.mli > unbuilt.txt
  [1]
  $ merlint -r E425 good.mli > unbuilt-good.txt
  $ diff built.txt unbuilt.txt
  $ diff built-good.txt unbuilt-good.txt
