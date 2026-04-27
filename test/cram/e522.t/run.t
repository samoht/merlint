Test bad example - foo/lib/foo_bar.ml has package-prefixed module name:
  $ merlint -B -r E522 bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E522] Package-prefixed module in main lib/ instead of wrapped submodule (1 issue)
    Rename <pkg>/lib/<pkg>_foo.ml to <pkg>/lib/foo.ml (and update the .mli
    similarly). Dune's default wrapped mode will expose it as <Pkg>.Foo. For
    something that really needs its own public name, create a sublib directory
    (<pkg>/lib_foo/ with its own dune) instead.
    - (global) foo/lib/foo_bar.ml uses package-prefixed module name; drop the prefix and let dune's wrapping expose it as a submodule, or move it into a sublib directory
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬────────────────────────────────────────────────────────╮
  │ Category          │ Issues                                                 │
  ├───────────────────┼────────────────────────────────────────────────────────┤
  │ Project Structure │ 1 (1 package-prefixed module in main lib/ instead of   │
  │                   │ wrapped submodule)                                     │
  ╰───────────────────┴────────────────────────────────────────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - foo/lib/bar.ml has no package prefix:
  $ merlint -B -r E522 good/
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
