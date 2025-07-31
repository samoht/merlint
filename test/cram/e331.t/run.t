Test bad example - should find redundant function prefixes:
  $ merlint -r E331 bad.ml
  merlint: [ERROR] Command failed with exit code 1
  Warning: Failed to build project: Command failed with exit code 1
  Function type analysis may not work properly.
  Continuing with analysis...
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✗ Naming Conventions (13 total issues)
    [E331] Redundant Function Prefixes (13 issues)
    Functions prefixed with 'create_', 'make_', 'get_', or 'find_' can often omit
    the prefix when the remaining name is descriptive enough. For example,
    'create_user' can be just 'user', 'make_widget' can be 'widget', 'get_name'
    can be 'name', and 'find_user' can be 'user' (returning option). Keep the
    prefix only when it adds meaningful distinction or when the bare name would be
    ambiguous. In modules, 'Module.create_module' should be 'Module.v'.
    - bad.ml:13:0: Function 'create_user' has redundant 'create_' prefix - consider 'user' instead. Create_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:14:0: Function 'create_project' has redundant 'create_' prefix - consider 'project' instead. Create_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:15:0: Function 'create_widget' has redundant 'create_' prefix - consider 'widget' instead. Create_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:18:0: Function 'get_name' has redundant 'get_' prefix - consider 'name' instead. Get_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:19:0: Function 'get_email' has redundant 'get_' prefix - consider 'email' instead. Get_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:20:0: Function 'get_status' has redundant 'get_' prefix - consider 'status' instead. Get_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:23:0: Function 'find_user_by_id' has redundant 'find_' prefix - consider 'user_by_id' instead. Find_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:24:0: Function 'find_project_by_name' has redundant 'find_' prefix - consider 'project_by_name' instead. Find_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:40:0: Function 'create_temp_file' has redundant 'create_' prefix - consider 'temp_file' instead. Create_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:41:0: Function 'make_widget' has redundant 'make_' prefix - consider 'widget' instead. Make_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:42:0: Function 'get_current_time' has redundant 'get_' prefix - consider 'current_time' instead. Get_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:43:0: Function 'find_free_port' has redundant 'find_' prefix - consider 'free_port' instead. Find_ functions can often omit the prefix when the function name alone is descriptive.
    - bad.ml:44:0: Function 'find_next_available_port' has redundant 'find_' prefix - consider 'next_available_port' instead. Find_ functions can often omit the prefix when the function name alone is descriptive.
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  
  Summary: ✗ 13 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - should find no issues:
  $ merlint -r E331 good.ml
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
