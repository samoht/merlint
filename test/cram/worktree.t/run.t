A linked working tree holds only what is committed, so the local opam switch
the main tree carries is not in it and dune has no switch to build against.
merlint builds what it cannot read (rebuild.t), that build fails for want of
the switch, and every file still comes back with no artefact. A run that says
only "0 issues" would report that as a clean tree.

Set up a repository with a local switch and a second working tree of it:

  $ cd repo
  $ git init -q .
  $ git add -A
  $ git -c user.email=cram@example.com -c user.name=cram commit -qm "fixture"
  $ mkdir _opam
  $ git worktree add -q ../tree HEAD

The run in the linked tree names what is missing and the command that supplies
it, rather than leaving the reader with a count.

  $ cd ../tree
  $ merlint . 2>/dev/null | tail -3
  ✗ No issues found, but 2 files could not be checked, so some or all of the rules did not run on them. The warnings above name them and say why; -v names every one.
    This working tree has no opam switch of its own, so nothing here could be built. Link the switch of the tree it was branched from, then re-run:
      opam switch link $TESTCASE_ROOT/repo $TESTCASE_ROOT/tree

The main tree has its switch, so nothing is said about one there. The build
merlint ran failed for its own reason, and that is what the run points at.

  $ cd ../repo
  $ merlint . 2>/dev/null | tail -2
    merlint ran the build for this and no artefact appeared, so the build itself is what needs fixing. Run it and read what it reports:
      dune build --root $TESTCASE_ROOT/repo @check
