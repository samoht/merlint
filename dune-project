(lang dune 3.21)
(using directory-targets 0.1)
(name merlint)
(generate_opam_files true)


(source (tangled gazagnaire.org/merlint))

(package
 (name merlint)
 (synopsis "OCaml linter enforcing modern coding conventions")
 (description "An opinionated OCaml linter that enforces modern OCaml coding conventions and best practices")
 (maintainers "Thomas Gazagnaire <thomas@gazagnaire.org>")
 (authors "Thomas Gazagnaire <thomas@gazagnaire.org>")
 (license ISC)
 (depends
  ocaml
  dune
  jsont
  cmdliner
  merlin
  re
  fpath
  logs
  fmt
  astring
  sexplib0
  parsexp
  (alcotest :with-test)))