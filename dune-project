(lang dune 3.21)
(using mdx 0.4)
(using directory-targets 0.1)
(name merlint)
(generate_opam_files true)
(implicit_transitive_deps false)


(source (tangled gazagnaire.org/merlint))

(package
 (name merlint)
 (synopsis "OCaml linter enforcing modern coding conventions")
 (tags (org:blacksun cli test))
 (description "An opinionated OCaml linter that enforces modern OCaml coding conventions and best practices")
 (maintainers "Thomas Gazagnaire <thomas@gazagnaire.org>")
 (authors "Thomas Gazagnaire <thomas@gazagnaire.org>")
 (license ISC)
 (depends
  ocaml
  dune
  bytesrw
  cmdliner
  eio
  ocaml-merlin
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
  nox-tty
  vlog
  eio_main
  nox-memtrace
  ocaml-project-index
  dune-build-info
  (alcotest :with-test)
  (mdx :with-test)
  nox-loc))
