Test bad example - should find create/make that should be 'v':
  $ merlint -r E332 bad.ml
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (2 total issues)
    [E332] Prefer 'v' Constructor (2 issues)
    In OCaml modules, the idiomatic name for the primary constructor is 'v' rather
    than 'create' or 'make'. This follows the convention used by many standard
    libraries. For example, 'Module.create' should be 'Module.v'. This makes the
    API more consistent and idiomatic.
    - bad.ml:31:0: Function 'create' should be named 'v' - this is the idiomatic constructor name in OCaml modules
    - bad.ml:32:0: Function 'make' should be named 'v' - this is the idiomatic constructor name in OCaml modules
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E332 good.ml
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
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
