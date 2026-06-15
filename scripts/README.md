# Scripts

Build- and maintenance-time scripts for the merlint project.

## Git hooks

Install the pre-commit (auto-format + merlint) and commit-msg hooks with the
`precommit` tool rather than a bespoke script:

<!-- $MDX skip -->
```sh
$ opam install precommit
$ precommit init
```

The pre-commit hook runs `dune fmt` (auto-fixing the whole tree) and
`merlint --build .`, and works for both `git commit` and `git-x commit`. Pass
`--hooks fmt,ai` to install without the merlint check. Bypass in emergencies
with `git commit --no-verify` (or `git-x commit create --no-verify`).
