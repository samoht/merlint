Test E606: Test File in Wrong Test Stanza

Good tests in correct test stanza:
  $ merlint -r E606 good/ 2>&1 | grep -A10 "merlint analysis" | head -10
  Running merlint analysis...
  
  Analyzing 2 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)

Bad test files in wrong test stanza:
  $ merlint -r E606 bad/
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✗ Test Quality (2 total issues)
    [E606] Test File in Wrong Test Stanza (2 issues)
    Test files should be organized to match the library structure. Tests for
    modules in a library should be grouped together in a test stanza that matches
    the library name, or in a generic 'test' stanza.
    - bad/test_parser.ml:1:0: Test module 'test_parser' tests library 'parser_lib' but is in test stanza 'test_parser' (expected test stanza 'parser_lib' or 'test')
    - bad/test_utils.ml:1:0: Test module 'test_utils' tests library 'utils_lib' but is in test stanza 'test_parser' (expected test stanza 'utils_lib' or 'test')
  
  Summary: ✗ 2 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]
