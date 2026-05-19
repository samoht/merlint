Test bad example - declared test quality is missing:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E910 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E910] Package quality policy (1 issue)
    Add x-quality field to *.opam.template to declare required quality features.
    Merlint checks that declared features actually exist.
    - bad/pkg/dune-project:1:0: pkg: test required by x-quality but missing
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────────────╮
  │ Category          │ Issues                       │
  ├───────────────────┼──────────────────────────────┤
  │ Project Structure │ 1 (1 package quality policy) │
  ╰───────────────────┴──────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E910` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - declared quality exists:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E910 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 1 files
  
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
