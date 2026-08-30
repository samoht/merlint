Test bad example - code nested under foo/lib and foo/test, and public code
under scripts/ (an executable and a library):
Build bad fixture project:
  $ (cd bad && dune build @check)

  $ merlint --build -r E912 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 4 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (4 total issues)
    [E912] Package directory layout (4 issues)
    Organise each opam package into the standard top-level component directories:
    lib/ for libraries, bin/ for executables, test/ for tests, fuzz/ for fuzzers,
    bench/ for benchmarks, c/ for C codegen and examples/ for example programs. A
    scripts/ directory may hold the private helpers a package builds with
    (codegen, dune-configurator probes), executables and the libraries beside them
    alike; anything with a public_name belongs in bin/ or lib/. Sub-components
    nest under those roots (lib/<name>/ with test/<name>/, IO adapters in
    lib/eio/), never as new top-level directories (foo/lib/, foo/test/).
    - bad/pkg/foo/lib/dune:1:0: pkg: code in foo/lib/ is outside the standard package layout; move libraries under lib/, executables under bin/, tests under test/, fuzzers under fuzz/
    - bad/pkg/foo/test/dune:1:0: pkg: code in foo/test/ is outside the standard package layout; move libraries under lib/, executables under bin/, tests under test/, fuzzers under fuzz/
    - bad/pkg/scripts/dune:1:0: pkg: public code in scripts/; scripts/ holds private helpers, public executables live in bin/ and public libraries in lib/
    - bad/pkg/scripts/pins/dune:1:0: pkg: public code in scripts/pins/; scripts/ holds private helpers, public executables live in bin/ and public libraries in lib/
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────╮
  │ Category          │ Issues                         │
  ├───────────────────┼────────────────────────────────┤
  │ Project Structure │ 4 (4 package directory layout) │
  ╰───────────────────┴────────────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E912` for the rule's description, hint, and good/bad examples.
  [1]

Test good example - code in top-level lib/ and test/, with a private helper
executable and a private helper library under scripts/:
Build good fixture project:
  $ (cd good && dune build @check)

  $ merlint --build -r E912 good/
  Dune root: $TESTCASE_ROOT/good/
  Running merlint analysis...
  
  Analyzing 4 files
  
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
