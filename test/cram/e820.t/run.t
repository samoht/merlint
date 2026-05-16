Test bad example - test.ml hand-rolls CSV parsing:
  $ merlint -B -r E820 bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E820] Hand-rolled CSV parsing (1 issue)
    Use csv (Csv.decode_file with a Csv.Row codec) for CSV trace parsing. Never
    hand-roll CSV readers with open_in/input_line/split_on_char.
    - bad/foo/test/interop/oracle/test.ml:1:0: Interop test bad/foo/test/interop/oracle/test.ml hand-rolls CSV parsing instead of csv
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬───────────────────────────────╮
  │ Category        │ Issues                        │
  ├─────────────────┼───────────────────────────────┤
  │ Interop Testing │ 1 (1 hand-rolled csv parsing) │
  ╰─────────────────┴───────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E820` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - test.ml uses csv library:
  $ merlint -B -r E820 good/
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
