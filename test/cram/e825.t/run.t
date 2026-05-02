Test bad example - CSV traces but no csv lib in dune:
  $ merlint -B -r E825 bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E825] Missing csv dependency (1 issue)
    Interop tests with CSV traces should use csv for parsing. Add csv to the
    (libraries ...) in the dune file and use Csv.decode_file with a Row codec.
    - bad/foo/test/interop/oracle/dune:1:0: Interop test bad/foo/test/interop/oracle has CSV traces but dune lacks csv dependency
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬──────────────────────────────╮
  │ Category        │ Issues                       │
  ├─────────────────┼──────────────────────────────┤
  │ Interop Testing │ 1 (1 missing csv dependency) │
  ╰─────────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - CSV traces with csv lib in dune:
  $ merlint -B -r E825 good/
  Running merlint analysis...
  
  Analyzing 0 files
  
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
