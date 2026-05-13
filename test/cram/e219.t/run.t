Test bad example - flags useless and-bindings while sparing genuine mutual recursion:
  $ merlint -B -r E219 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (4 total issues)
    [E219] Useless [and] in [let rec ... and ...] groups (4 issues)
    A [let rec f and g and h] chain only needs the [and] when at least one binding
    calls another binding in the group. When [h] references neither [f] nor [g]
    (and isn't recursive itself), the [and] is just a coupling: future readers
    assume the bindings are co-dependent. Lift the standalone binding to its own
    [let] above or below the group. The same applies inside expressions: [let rec
    ... and ... in body] follows the same rule.
    - bad.ml:17:0: [scope_of] is part of [let rec ... and ...] but isn't mutually recursive with its siblings: extract [scope_of] from the [let rec scope_of, scope_in_items, scope_in_item] group as a plain [let]
    - bad.ml:22:0: [scope_in_items] is part of [let rec ... and ...] but isn't mutually recursive with its siblings: extract [scope_in_items] from the [let rec scope_of, scope_in_items, scope_in_item] group as a plain [let]
    - bad.ml:27:0: [scope_in_item] is part of [let rec ... and ...] but isn't mutually recursive with its siblings: extract [scope_in_item] from the [let rec scope_of, scope_in_items, scope_in_item] group as its own [let rec]
    - bad.ml:41:0: [double] is part of [let rec ... and ...] but isn't mutually recursive with its siblings: extract [double] from the [let rec is_even, is_odd, double] group as a plain [let]
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭────────────┬─────────────────────────────────────────────────────╮
  │ Category   │ Issues                                              │
  ├────────────┼─────────────────────────────────────────────────────┤
  │ Code Style │ 4 (4 useless [and] in [let rec ... and ...] groups) │
  ╰────────────┴─────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - no flags after linearisation:
  $ merlint -B -r E219 good.ml
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
