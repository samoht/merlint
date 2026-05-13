Test bad example - pure sans-IO package depends on Unix:
  $ merlint -B -r E930 bad/
  Running merlint analysis...
  
  Analyzing 1 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (1 total issues)
    [E930] Sans-IO policy (1 issue)
    Any package tagged codec.* or protocol must follow the sans-IO contract. The
    org standardises on Eio: no package may depend on lwt, miou, or mirage
    runtimes. Pure sans-IO packages (codec.* / protocol without an eio tag) must
    additionally not depend on eio*, unix, or ambient clocks. They expose Bytesrw
    Reader/Writer in the main library rather than shipping a separate
    <pkg>_bytesrw sub-library.
    - pkg/pkg.opam:1:0: pkg/pkg.opam: sans-io policy violated by depends: unix
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬──────────────────────╮
  │ Category          │ Issues               │
  ├───────────────────┼──────────────────────┤
  │ Project Structure │ 1 (1 sans-io policy) │
  ╰───────────────────┴──────────────────────╯
  
  
  Summary: ✗ 1 total issue (applied 1 rule)
  ✗ Some checks failed. See details above.
  [1]

Test good example - pure sans-IO package avoids runtime IO dependencies:
  $ merlint -B -r E930 good/
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
