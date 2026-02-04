(lang dune 3.0)
(using directory-targets 0.1)
(name merlint)
(generate_opam_files true)

(package
 (name merlint)
 (synopsis "OCaml linter enforcing modern coding conventions")
 (description "An opinionated OCaml linter that enforces modern OCaml coding conventions and best practices")
 (maintainers "Thomas Gazagnaire")
 (authors "Merlint Contributors")
 (license "ISC")
 (homepage "https://github.com/samoht/merlint")
 (bug_reports "https://github.com/samoht/merlint/issues")
 (depends
  ocaml
  dune
  yojson
  cmdliner
  merlin
  re
  fpath
  logs
  fmt
  astring
  sexplib0
  parsexp
  ppxlib
  (alcotest :with-test)))