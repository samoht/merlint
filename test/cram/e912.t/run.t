Test bad example - code nested under foo/lib and foo/test:
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E912 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 3 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (3 total issues)
    [E912] Package directory layout (3 issues)
    Organise each opam package into the standard top-level component directories:
    lib/ for libraries, bin/ for executables, test/ for tests, fuzz/ for fuzzers,
    bench/ for benchmarks, c/ for C codegen and examples/ for example programs. A
    scripts/ directory may hold private helper executables (codegen,
    dune-configurator probes); anything with a public_name belongs in bin/.
    Sub-components nest under those roots (lib/<name>/ with test/<name>/, IO
    adapters in lib/eio/), never as new top-level directories (foo/lib/,
    foo/test/).
    - bad/pkg/foo/lib/dune:1:0: pkg: code in foo/lib/ is outside the standard package layout; move libraries under lib/, executables under bin/, tests under test/, fuzzers under fuzz/
    - bad/pkg/foo/test/dune:1:0: pkg: code in foo/test/ is outside the standard package layout; move libraries under lib/, executables under bin/, tests under test/, fuzzers under fuzz/
    - bad/pkg/scripts/dune:1:0: pkg: public executable in scripts/; scripts/ holds private helper executables, public executables live in bin/
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────╮
  │ Category          │ Issues                         │
  ├───────────────────┼────────────────────────────────┤
  │ Project Structure │ 3 (3 package directory layout) │
  ╰───────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E912` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - code in top-level lib/ and test/:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E912 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 3 files
  
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
