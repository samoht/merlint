Test bad example - should find redundant module name:
  $ merlint -r E320 bad.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (1 total issues)
    [E320] Long Identifier Names
    This issue means your identifier has too many underscores (more than 4) making
    it hard to read. Fix it by removing redundant prefixes and suffixes:  • In
    test files: remove 'test_' prefix (e.g., test_check_foo → check_foo or just
    foo) • In hint files: remove '_hint' suffix (e.g., complexity_hint →
    complexity) • In modules: remove '_module' suffix (e.g., parser_module →
    parser) • Remove redundant words that repeat the context (e.g.,
    check_mli_doc → check_mli)  The file/module context already makes the
    purpose clear.
    - bad.ml:1:4: 'get_user_profile_data_from_database_by_id' has too many underscores (7)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 1 total issues
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E320 good.ml
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 0 total issues
  ✗ Some checks failed. See details above.
