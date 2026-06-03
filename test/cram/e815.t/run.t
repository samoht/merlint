Test bad example - regen rule runs generate.sh without a REGEN gate:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E815 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
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

Test good example - regen rule is a REGEN-gated promote rule:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E815 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
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
