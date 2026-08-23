A key merlint has no case for is a typo, a key that was renamed, or one from a
merlint that never existed. Reading past it would leave the file looking like
configuration that is in force when none of it is, and the rule it configures
running at its default.

  $ cat > dune-project <<EOF
  > (lang dune 3.0)
  > EOF

A near miss of a real key is refused with the key that was meant, in the
separator style it was written in, so the fix is one edit:

  $ cat > merlint.toml <<EOF
  > disalowed-modules = ["Stdlib.Printf"]
  > EOF
  $ merlint .
  merlint config: ./merlint.toml: unknown key "disalowed-modules" -- did you mean "disallowed-modules"?
  [1]

  $ cat > merlint.toml <<EOF
  > require_mli_file = false
  > EOF
  $ merlint .
  merlint config: ./merlint.toml: unknown key "require_mli_file" -- did you mean "require_mli_files"?
  [1]

A key close to nothing merlint knows is refused without a guess:

  $ cat > merlint.toml <<EOF
  > banana = 3
  > EOF
  $ merlint .
  merlint config: ./merlint.toml: unknown key "banana". Run `merlint help config` for the keys merlint accepts.
  [1]

Every documented key stays accepted, including [workspace], which Project reads
rather than Config:

  $ cat > merlint.toml <<EOF
  > max-complexity = 15
  > allowed_words = ["EdDSA"]
  > acronyms = ["ECDSA"]
  > disallowed_libraries = ["fmt"]
  > require-mli-files = true
  > workspace = "."
  > EOF
  $ merlint --show-config . | sed -n '6,8p'
  Settings:
    max-complexity: 15
    max-function-length: 50
