Test bad example - generate.sh uses pip install --break-system-packages:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E835 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✓ Project Structure (0 total issues)
  ✓ Test Quality (0 total issues)
  ✗ Interop Testing (1 total issues)
    [E835] pip install --break-system-packages (1 issue)
    Python deps must live in a venv. Never use pip install
    --break-system-packages. The generate.sh wrapper should create/reuse a venv
    automatically.
    - bad/foo/test/interop/oracle/scripts/generate.sh:1:0: bad/foo/test/interop/oracle/scripts/generate.sh uses --break-system-packages
  ✓ Code Generation (0 total issues)
  
  ╭─────────────────┬───────────────────────────────────────────╮
  │ Category        │ Issues                                    │
  ├─────────────────┼───────────────────────────────────────────┤
  │ Interop Testing │ 1 (1 pip install --break-system-packages) │
  ╰─────────────────┴───────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E835` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - generate.sh uses a venv:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E835 good/
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
