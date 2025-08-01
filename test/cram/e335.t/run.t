Test bad example - should find used underscore-prefixed binding:
  $ merlint -r E335 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E335] Used Underscore-Prefixed Binding (1 issue)
    Bindings prefixed with underscore (like '_x') indicate they are meant to be
    unused. If you need to use the binding, remove the underscore prefix. If the
    binding is truly unused, consider using a wildcard pattern '_' instead. Note:
    PPX-generated code with double underscore prefix (like '__ppx_generated') is
    excluded from this check.
    - bad.ml:1:4: Underscore-prefixed binding '_debug_mode' is used 1 time - underscore prefix indicates unused bindings
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test PPX-generated code - should only flag regular underscore bindings:
  $ merlint -r E335 ppx_generated.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E335] Used Underscore-Prefixed Binding (1 issue)
    Bindings prefixed with underscore (like '_x') indicate they are meant to be
    unused. If you need to use the binding, remove the underscore prefix. If the
    binding is truly unused, consider using a wildcard pattern '_' instead. Note:
    PPX-generated code with double underscore prefix (like '__ppx_generated') is
    excluded from this check.
    - ppx_generated.ml:9:6: Underscore-prefixed binding '_regular_underscore' is used 1 time - underscore prefix indicates unused bindings
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E335 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rule)
  ✓ All checks passed!
