A linked working tree holds only what is committed, so the local opam switch
the main tree carries is not in it and dune has no switch to build against.
merlint builds what it cannot read (rebuild.t), that build fails for want of
the switch, and the run is refused: a tree nothing could be built in is a tree
merlint has no verdict about, and "0 issues" would read as a clean one. What
merlint adds to dune's answer is the cure, which it can recognise here and dune
cannot. It goes to stderr with the rest of the refusal.

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
  $ merlint . 2>&1 >/dev/null | tail -3
    This working tree has no opam switch of its own, so nothing here could be built. Link the switch of the tree it was branched from, then re-run:
      opam switch link $TESTCASE_ROOT/repo $TESTCASE_ROOT/tree
  merlint: nothing was analysed, because a verdict computed without the artefacts its rules read is not a verdict about this code.

The main tree has its switch, so nothing is said about one there. The build
merlint ran failed for its own reason, and dune's own words are what the
refusal carries.

  $ cd ../repo
  $ merlint . 2>&1 >/dev/null | tail -2
  -> required by alias lib/check
  merlint: nothing was analysed, because a verdict computed without the artefacts its rules read is not a verdict about this code.
