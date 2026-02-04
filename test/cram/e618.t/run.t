Test bad example - should find double underscore patterns:
  $ merlint -r E618 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (2 total issues)
    [E618] Avoid X__Y Module Access (2 issues)
    Avoid using double underscore module access like 'Module__Submodule'. Use dot
    notation 'Module.Submodule' instead. Double underscore notation is internal to
    the OCaml module system and should not be used in application code.
    - bad.ml:1:15: Use 'Printf.sprintf.sprintf' instead of 'Printf__sprintf.sprintf' - avoid double underscore module access
    - bad.ml:2:15: Use 'String.length.length' instead of 'String__length.length' - avoid double underscore module access
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E618 good.ml
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
