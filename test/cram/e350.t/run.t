Test bad example - should find Printf module usage:
  $ merlint -r E350 bad.ml
  File "bad.ml", line 6, characters 4-5:
  6 | let w = create_window true false true
          ^
  Error (warning 32 [unused-value-declaration]): unused value w.
  File "good.ml", line 10, characters 4-5:
  10 | let w = create_window ~visibility:Visible ~mode:Fullscreen ~resizable:Fixed_size
           ^
  Error (warning 32 [unused-value-declaration]): unused value w.
  merlint: [ERROR] Dune build failed with exit code 1
  Warning: Dune build failed with exit code 1
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
  
  Summary: ✓ 0 total issues
  ✓ All checks passed!

Test good example - should find no issues:
  $ merlint -r E350 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✓ 0 total issues
  ✓ All checks passed!
