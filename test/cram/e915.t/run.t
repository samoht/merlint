Test bad example - three packages each with a different tag problem:
  $ merlint -B -r E915 bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (3 total issues)
    [E915] Opam tag metadata (3 issues)
    Runs only when the project root has a sources.toml (monopam monorepo marker)
    or a categories.toml (the tag vocabulary). When it does run, every *.opam must
    declare tags: ["org:<your-org>" "<topic>" ...] where each topic is a slug from
    categories.toml / merlint.toml's topics list. Edit the package's dune-project
    so dune regenerates the opam file.
    - pkg1/pkg1.opam:1:0: pkg1/pkg1.opam: missing tags: field
    - pkg2/pkg2.opam:1:0: pkg2/pkg2.opam: tags: missing org:* marker
    - pkg3/pkg3.opam:1:0: pkg3/pkg3.opam: unknown topic "weird-new-topic"
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────╮
  │ Category          │ Issues                  │
  ├───────────────────┼─────────────────────────┤
  │ Project Structure │ 3 (3 opam tag metadata) │
  ╰───────────────────┴─────────────────────────╯
  
  
  Summary: ✗ 3 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]







Test good example - well-formed opam metadata:
  $ merlint -B -r E915 good/
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



