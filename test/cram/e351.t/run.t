Test bad example - should find global mutable state:
  $ merlint -r E351 bad.ml
  File "bad.ml", line 3, characters 4-16:
  3 | let incr_counter () = counter := !counter + 1
          ^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value incr_counter.
  
  File "bad.ml", line 6, characters 4-18:
  6 | let cached_results = Hashtbl.create 100
          ^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value cached_results.
  File "good.ml", line 2, characters 4-15:
  2 | let compute_sum lst =
          ^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value compute_sum.
  merlint: [ERROR] Dune build failed with exit code 1
  Warning: Dune build failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✗ Code Quality (2 total issues)
    [E351] Global Mutable State
    Global mutable state makes programs harder to reason about and test. Consider
    using immutable data structures and passing state explicitly through function
    parameters. If mutation is necessary, consider using local state within
    functions or monadic patterns.
    - bad.ml:2:0: Global mutable state 'counter' of type 'ref' detected - consider using functional patterns instead
    - bad.ml:5:0: Global mutable state 'global_cache' of type 'array' detected - consider using functional patterns instead
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues (applied 1 rules)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E351 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues (applied 1 rules)
  ✓ All checks passed!
