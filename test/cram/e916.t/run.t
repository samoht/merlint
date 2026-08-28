A `(pin ...)` stanza names the exact revision its packages are built from.
`dune pkg lock` does not fail when it cannot honour one: it resolves the
package from somewhere else and records that in the lock, so the build links
source no declaration names and nothing says so.

A lock directory is gitignored tree-wide, so both fixtures write their own.
The sandbox keeps whatever a run leaves behind, so they are put back to a
known state first:

  $ rm -rf bad/dune.lock good/dune.lock
  $ mkdir bad/dune.lock good/dune.lock

The bad project declares four pins and the lock honours none of them. tw's
entry is the release archive: a pin whose (package ...) names no version makes
the package .dev, which satisfies no version constraint and loses to the
released package.

  $ cat > bad/dune.lock/tw.1.0.0.pkg <<'EOF'
  > (version 1.0.0)
  > 
  > (build
  >  (all_platforms ((dune))))
  > 
  > (source
  >  (fetch
  >   (url https://github.com/samoht/tw/archive/refs/tags/v1.0.0.tar.gz)
  >   (checksum
  >    sha256=6e1a8d0c1c2e4a3b5f7d9c0b2a4e6f8091a3b5c7d9e1f3a5b7c9d1e3f5a7b9c1)))
  > EOF

cascade's entry is another revision of the pinned repository:

  $ cat > bad/dune.lock/cascade.dev.pkg <<'EOF'
  > (version dev)
  > 
  > (source
  >  (fetch
  >   (url
  >    git+https://github.com/samoht/cascade.git#01159e579f4d2f2e0c8b6a4d3e1f7c9a5b2d8e60)))
  > 
  > (dev)
  > EOF

uutf is pinned to a branch. The lock records that same string, and the two
matching still says nothing about what was fetched:

  $ cat > bad/dune.lock/uutf.dev.pkg <<'EOF'
  > (version dev)
  > 
  > (source
  >  (fetch (url git+https://github.com/dbuenzli/uutf.git#main)))
  > 
  > (dev)
  > EOF

helix is pinned and gets no entry written at all.

  $ merlint -r E916 bad/
  Dune root: $TESTCASE_ROOT/bad/
  Running merlint analysis...
  
  Analyzing 0 files
  
  ✓ Code Quality (0 total issues)
  ✓ Code Style (0 total issues)
  ✓ Naming Conventions (0 total issues)
  ✓ Documentation (0 total issues)
  ✗ Project Structure (4 total issues)
    [E916] Unhonoured source pin (4 issues)
    A (pin ...) stanza names the exact revision its packages are built from, and
    `dune pkg lock` resolves the package from somewhere else rather than failing
    when it cannot honour one -- an overlay's copy, or the released archive, which
    beats a pin that names no version. Re-run `dune pkg lock` and check the entry
    again; if the pinned revision still does not win, give the pin's (package ...)
    a (version ...) so the release cannot outrank it, or point the pin at a
    revision that exists.
    - bad/dune-project:1:0: uutf: pinned to git+https://github.com/dbuenzli/uutf.git#main, which names no revision to check against
    - bad/dune-project:1:0: helix: the lock has no entry for it
    - bad/dune-project:1:0: cascade: pinned to git+https://github.com/samoht/cascade.git#cc6b4238b98d75eb574a66dd29c85532312a1c75, and the lock resolves git+https://github.com/samoht/cascade.git#01159e579f4d2f2e0c8b6a4d3e1f7c9a5b2d8e60
    - bad/dune-project:1:0: tw: pinned to git+https://github.com/samoht/tw.git#43f7afe60f28539b6ccba7c97c690139de55ca79, and the lock resolves https://github.com/samoht/tw/archive/refs/tags/v1.0.0.tar.gz
  ✓ Test Quality (0 total issues)
  ✓ Interop Testing (0 total issues)
  ✓ Code Generation (0 total issues)
  
  ╭───────────────────┬─────────────────────────────╮
  │ Category          │ Issues                      │
  ├───────────────────┼─────────────────────────────┤
  │ Project Structure │ 4 (4 unhonoured source pin) │
  ╰───────────────────┴─────────────────────────────╯
  
  
  Summary: ✗ 4 total issues (applied 1 rule)
  ✗ Some checks failed. See details above.
    Run `merlint help E916` for the rule's description, hint, and good/bad examples.
  [1]

The good project pins two sources over three packages, and every entry records
the revision its pin names. fmt is in the lock and in no pin, so it is not
compared against anything.

  $ cat > good/dune.lock/tw.1.0.1.pkg <<'EOF'
  > (version 1.0.1)
  > 
  > (build
  >  (all_platforms ((dune))))
  > 
  > (source
  >  (fetch
  >   (url
  >    git+https://github.com/samoht/tw.git#43f7afe60f28539b6ccba7c97c690139de55ca79)))
  > EOF

  $ cat > good/dune.lock/eio.2.0.0.pkg <<'EOF'
  > (version 2.0.0)
  > 
  > (source
  >  (fetch
  >   (url
  >    git+https://github.com/ocaml-multicore/eio.git#085cce2e110b53aa3002a2cdb28502c3f297d374)))
  > EOF

  $ cat > good/dune.lock/eio_main.2.0.0.pkg <<'EOF'
  > (version 2.0.0)
  > 
  > (source
  >  (fetch
  >   (url
  >    git+https://github.com/ocaml-multicore/eio.git#085cce2e110b53aa3002a2cdb28502c3f297d374)))
  > EOF

  $ cat > good/dune.lock/fmt.0.11.0.pkg <<'EOF'
  > (version 0.11.0)
  > 
  > (source
  >  (fetch
  >   (url https://erratique.ch/software/fmt/releases/fmt-0.11.0.tbz)
  >   (checksum
  >    sha512=3f40155fc6a7315202e410585964307d63416c8001fd243667ed9d8d1a02b67d)))
  > EOF

  $ merlint -r E916 good/
  Dune root: $TESTCASE_ROOT/good/
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

A project with pins and no lock directory has nothing to check them against,
so the rule is silent rather than reporting every pin as unresolved:

  $ rm -rf good/dune.lock
  $ merlint -r E916 good/
  Dune root: $TESTCASE_ROOT/good/
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
