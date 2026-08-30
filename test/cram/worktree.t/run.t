A linked working tree holds only what is committed, so ignored companions the
main tree carries are absent from it. That fact does not establish why a build
failed: an ambient switch may satisfy dune, or the failure may be unrelated to
opam. Merlint builds what it cannot read (rebuild.t), relays the build's own
answer, and refuses the run. A tree nothing could be built in is a tree merlint
has no verdict about, and "0 issues" would read as a clean one; inventing a
switch remedy would replace that honest refusal with a diagnosis the tree
cannot support.

Set up a repository with a local switch and a second working tree of it:

  $ cd repo
  $ git init -q .
  $ git add -A
  $ git -c user.email=cram@example.com -c user.name=cram commit -qm "fixture"
  $ mkdir _opam
  $ git worktree add -q ../tree HEAD

The run in the linked tree relays dune's dependency chain and refuses without
claiming that the absent local switch caused it.

  $ cd ../tree
  $ merlint . 2>&1 >/dev/null | tail -3
  -> required by _build/default/lib/.demo.objs/byte/demo.cmi
  -> required by alias lib/check
  merlint: nothing was analysed, because a verdict computed without the artefacts its rules read is not a verdict about this code.

The main tree follows the same rule. The build merlint ran failed for its own
reason, and dune's own words are what the refusal carries.

  $ cd ../repo
  $ merlint . 2>&1 >/dev/null | tail -2
  -> required by alias lib/check
  merlint: nothing was analysed, because a verdict computed without the artefacts its rules read is not a verdict about this code.
