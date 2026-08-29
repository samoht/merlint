(lang dune 3.21)
(using mdx 0.4)
(using directory-targets 0.1)
(name merlint)
(generate_opam_files true)
(implicit_transitive_deps false)


(license ISC)
(source (tangled gazagnaire.org/merlint))

(package
 (name merlint)
 (synopsis "OCaml linter enforcing modern coding conventions")
 (tags (org:blacksun cli test))
 (description "An opinionated OCaml linter that enforces modern OCaml coding conventions and best practices")
 (maintainers "Thomas Gazagnaire <thomas@gazagnaire.org>")
 (authors "Thomas Gazagnaire <thomas@gazagnaire.org>")
 (depends
  ocaml
  bytesrw
  cmdliner
  eio
  merlin
  merlin-lib
  re
  fpath
  logs
  fmt
  base-unix
  astring
  nox-sexp
  nox-dune
  nox-opam
  nox-toml
  nox-json
  console
  console-eio
  probe
  observe
  eio_main
  project-index
  dune-build-info
  (alcotest :with-test)
  (mdx :with-test)))
