(lang dune 3.0)
(name cyclomatic)
(generate_opam_files true)

(package
 (name cyclomatic)
 (synopsis "OCaml cyclomatic complexity analyzer")
 (description "A tool to analyze OCaml source code and report functions that exceed complexity or length thresholds")
 (maintainers "Thomas Gazagnaire")
 (authors "Cyclomatic Authors")
 (license "MIT")
 (homepage "https://github.com/example/cyclomatic")
 (bug_reports "https://github.com/example/cyclomatic/issues")
 (depends
  ocaml
  dune
  yojson
  cmdliner
  merlin))