A type expression is a graph, not a tree, and [-rectypes] is where that shows:
[int -> 'a as 'a] is its own return type, and ['a box as 'a] is its own type
argument. Every walk merlint makes over a type used to follow such a loop with
nothing to stop it. [typed_arg_labels] built an infinite list of argument
labels, so the lazy holding a file's typed declarations died of Stack_overflow;
[Fun.protect] memoizes that exception, so the one fault came back on every rule
that asked for those declarations and a scoped run reported six crashed checks
-- E005, E325, E330, E333, E336 and E350. E106 walks a type of its own and did
not crash: it ran until it was killed.

The walks carry an occurs check now -- the nodes open on the path from the root
of the walk, with a node already open not followed a second time. It is not a
depth cap. The nodes reachable from a type are finite and each step opens one
more, so the depth is bounded by the type itself: a finite type is walked
whole, and only a cycle is cut, once round. A cap would stop a large honest
type part-way and report the short answer as the whole one.

  $ dune build @check

The cyclic declarations are analysed rather than crashing the run, and the
finite ones beside them are still reported. A guard that terminated by skipping
the type would have silenced these two findings, so the transcript says the
walks still reach the end of a type rather than stopping at its first node:

  $ merlint --build -r E005+E106+E325+E330+E333+E336+E350 cyclic.ml
  Dune root: $TESTCASE_ROOT/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (1 total issues)
    [E350] Boolean Blindness (1 issue)
    Functions with multiple boolean parameters are hard to use correctly. It's
    easy to mix up the order of arguments at call sites. Consider using variant
    types, labeled arguments, or a configuration record instead.
    - cyclic.ml:26:0: Function 'create_window' has 2 boolean parameters - consider using a variant type or record for clarity
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E325] Function Naming Convention (1 issue)
    Functions that return option types should be prefixed with 'find_', while
    functions that return non-option types should be prefixed with 'get_'. This
    convention helps communicate the function's behavior to callers.
    - cyclic.ml:25:0: Function 'get_first' naming convention: consider 'find_first'
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────────────┬──────────────────────────────────╮
  │ Category           │ Issues                           │
  ├────────────────────┼──────────────────────────────────┤
  │ Code Quality       │ 1 (1 boolean blindness)          │
  │ Naming Conventions │ 1 (1 function naming convention) │
  ╰────────────────────┴──────────────────────────────────╯
  
  
  Summary: ✗ 2 total issues (applied 7 rules)
  ✗ Some checks failed. See details above.
    Run `merlint help E325` for the rule's description, hint, and good/bad examples.
  [1]
