Bad: a protocol state module whose message match silently accepts an
unexpected message via a wildcard arm that returns a normal value.
  $ (cd bad/proto && dune build @check)
  $ merlint --build -r E951 bad/

Good: a protocol state module that rejects an unexpected message (Error)
and a fully exhaustive match with no wildcard.
  $ (cd good/proto && dune build @check)
  $ merlint --build -r E951 good/
