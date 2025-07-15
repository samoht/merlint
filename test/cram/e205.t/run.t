Test bad example - should find bad module naming:
  $ merlint -r E205 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✗ Code Style (2 total issues)
    [E205] Consider Using Fmt Module
    This is a style suggestion. While Printf and Format are part of OCaml's
    standard library and perfectly fine to use, the Fmt library offers additional
    features like custom formatters and better composability. Consider using Fmt
    for new code, but Printf/Format remain valid choices for many use cases.
    - bad.ml:2:2: Use Fmt module instead of Printf
    - bad.ml:4:2: Use Fmt module instead of Printf
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 2 total issues
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E205 good.ml
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
