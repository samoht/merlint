Test bad example - polymorphic comparison on non-scalar types:
  $ dune build @check
  $ merlint --build -r E106 bad.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (5 total issues)
    [E106] Polymorphic comparison (5 issues)
    OCaml's structural (=), (<>), (<), (>), (<=), (>=), compare, min, max and
    Hashtbl.hash compare values by walking their runtime representation. On a
    non-scalar type this is unsafe: it ignores abstraction boundaries (comparing
    the concrete representation behind an abstract type), raises Invalid_argument
    at runtime when a value contains a function, and gives wrong answers for types
    with a custom notion of equality. Call the type's own equal, compare or hash -
    every type module should expose them - and have a genuinely generic function
    take an ~equal or ~compare parameter. Comparing scalars (int, char, string,
    bytes, float, bool, unit, the fixed-width int types), transparent containers
    (list, array, option) and tuples of those is fine, and so is comparing against
    a nullary constructor ([], None, an enum tag), which is just a tag check.
    - bad.ml:5:31: Polymorphic (=) used on a non-scalar type - use the type's own equal/compare/hash instead
    - bad.ml:8:28: Polymorphic compare used on a non-scalar type - use the type's own equal/compare/hash instead
    - bad.ml:11:31: Polymorphic (=) used on a non-scalar type - use the type's own equal/compare/hash instead
    - bad.ml:14:33: Polymorphic (=) used on a non-scalar type - use the type's own equal/compare/hash instead
    - bad.ml:17:22: Polymorphic Hashtbl.hash used on a non-scalar type - use the type's own equal/compare/hash instead
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
  │ Code Quality │ 5 (5 polymorphic comparison) │
  ╰──────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 5 total issues (applied 1 rule)
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
