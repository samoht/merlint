Test bad example - python script without requirements.txt:
  $ merlint -B -r E805 bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E805] Missing requirements.txt (1 issue)
    Python oracles must pin dependencies in requirements.txt with exact versions
    (e.g. crcmod==1.7). This ensures reproducible trace generation without
    depending on local installs.
    - (global) Python oracle bad/foo/test/interop/oracle/scripts/ missing requirements.txt
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬────────────────────────────────╮
  │ Category        │ Issues                         │
  ├─────────────────┼────────────────────────────────┤
  │ Interop Testing │ 1 (1 missing requirements.txt) │
  ╰─────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - python script with requirements.txt:
  $ merlint -B -r E805 good/
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
