Test bad example - polymorphic comparison on non-scalar types:
  $ dune build @check
  $ merlint --build -r E106 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (6 total issues)
    [E106] Polymorphic comparison (6 issues)
    OCaml's structural (=), (<>), (<), (>), (<=), (>=), compare, min, max and
    Hashtbl.hash compare values by walking their runtime representation. On a type
    from the current module that is fine - you can see its representation, and you
    expose your own equal in the .mli - but on another module's type it walks past
    the abstraction (ordering two abstract handles leaks their hidden contents),
    and on a function it raises Invalid_argument at runtime. Across modules, call
    that type's own equal, compare or hash. Comparing scalars, transparent
    containers (list, array, option) and tuples of those is always fine, as is a
    tag check against a nullary constructor ([], None, an enum tag). Defining a
    type's own equal or compare with these operators inside its defining module -
    let equal a b = a = b - is fine and not flagged: there you see the
    representation and are the authority on whether it is sound.
    - bad.ml:14:27: Polymorphic (=) - use Id.equal instead
    - bad.ml:17:28: Polymorphic compare - use Id.compare instead
    - bad.ml:20:21: Polymorphic Hashtbl.hash - use Id.hash instead
    - bad.ml:23:27: Polymorphic (=) - use Re.equal instead
    - bad.ml:26:33: Polymorphic (=) - comparing a function value raises Invalid_argument at runtime
    - bad.ml:29:22: Polymorphic (>) - use Id.compare instead
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭──────────────┬──────────────────────────────╮
  │ Category     │ Issues                       │
  ├──────────────┼──────────────────────────────┤
  │ Code Quality │ 6 (6 polymorphic comparison) │
  ╰──────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 6 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E106` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - should find no issues:
  $ merlint --build -r E106 good.ml
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
