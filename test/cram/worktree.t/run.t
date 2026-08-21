A linked working tree holds only what is committed, so the local opam switch
the main tree carries is not in it and dune has no switch to build against.
Every file then comes back with no artefact, and a run that says only "0 issues"
would report that as a clean tree.

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
  ✗ No issues found, but 2 files could not be fully checked, so some of the rules that read a typedtree did not run on them. Re-run with -v to name them and say why.
    This working tree has no opam switch of its own, so nothing here could be built. Link the switch of the tree it was branched from, then re-run:
      opam switch link $TESTCASE_ROOT/repo $TESTCASE_ROOT/tree

The main tree has its switch, so nothing is said about one there; its files are
unchecked for the ordinary reason, that nobody has built them.

  $ cd ../repo
  $ merlint . 2>/dev/null | tail -1
  ✗ No issues found, but 2 files could not be fully checked, so some of the rules that read a typedtree did not run on them. Re-run with -v to name them and say why.
