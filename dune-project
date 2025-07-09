(lang dune 3.0)
(name merlint)
(generate_opam_files true)

(package
 (name merlint)
 (synopsis "OCaml linter enforcing project conventions")
 (description "An opinionated OCaml linter that enforces modern OCaml coding conventions")
 (maintainers "Thomas Gazagnaire")
 (authors "Merlint Authors")
 (license "MIT")
 (homepage "https://github.com/samoht/merlint")
 (bug_reports "https://github.com/samoht/merlint/issues")
 (depends
  ocaml
  dune
  yojson
  cmdliner
  merlin
  re
  (alcotest :with-test)))