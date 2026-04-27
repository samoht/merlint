Test bad example - generate.py defines its own encode function:
  $ merlint -B -r E830 bad/

Test good example - generate.py only calls the upstream library:
  $ merlint -B -r E830 good/
