open Merlint

(* Sample dune describe output for testing *)
let sample_dune_describe =
  Parsexp.Single.parse_string_exn
    {|((root /Users/samoht/git/cyclomatic)
 (build_context _build/default)
 (executables
  ((names (main))
   (requires
    (a5712c0fe1b0538db58231978dea3328
     c480a7c584d174c22d86dbdb79515d7d
     e8ae26164630a0adddebdc6c1d7d6950
     6f7186adbc64b83bab803daac023f331
     ef7d6b9b038adab35dcbac8bc8bb4a7f
     4b4e7296a197b1023321463e6c3fe23c
     e513e0e7f6de491e7321010ddbbc9fc8
     d30d796414dc498f7de506af329a456b
     936f38b80bf750be55ed02357e9cdc00))
   (modules
    (((name Main)
      (impl (_build/default/bin/main.ml))
      (intf ())
      (cmt (_build/default/bin/.main.eobjs/byte/dune__exe__Main.cmt))
      (cmti ()))))
     (include_dirs (_build/default/bin/.main.eobjs/byte))))
 (library
  ((name astring)
   (uid 5a95678ac1f03a0ac7c00991ad1e2686)
   (local false)
   (requires ())
   (source_dir /Users/samoht/git/cyclomatic/_opam/lib/astring)
   (modules ())
   (include_dirs (/Users/samoht/git/cyclomatic/_opam/lib/astring))))
 (library
  ((name merlint)
   (uid a5712c0fe1b0538db58231978dea3328)
   (local true)
   (requires
    (5a023480cf764a0038e5cc56267c3411
     7c82c98fd32b5f392f3ad8c940ef1e9e
     69b0916f09495cc8be752e83ba603480
     6f7186adbc64b83bab803daac023f331
     e513e0e7f6de491e7321010ddbbc9fc8
     5a95678ac1f03a0ac7c00991ad1e2686
     449445be7a24ce51e119d57e9e255d3f
     b5f1ee68ba5bd9694aa0f66e022e50fe))
   (source_dir _build/default/lib)
   (modules
    (((name Rule)
      (impl (_build/default/lib/rule.ml))
      (intf (_build/default/lib/rule.mli))
      (cmt (_build/default/lib/.merlint.objs/byte/merlint__Rule.cmt))
      (cmti (_build/default/lib/.merlint.objs/byte/merlint__Rule.cmti)))
     ((name Report)
      (impl (_build/default/lib/report.ml))
      (intf (_build/default/lib/report.mli))
      (cmt (_build/default/lib/.merlint.objs/byte/merlint__Report.cmt))
     (cmti (_build/default/lib/.merlint.objs/byte/merlint__Report.cmti))))))))
|}

let test_get_lib_modules () =
  let modules = Dune.get_lib_modules sample_dune_describe in
  Alcotest.(check (list string))
    "library modules" [ "Report"; "Rule" ]
    (List.sort String.compare modules)

let test_get_test_modules () =
  let modules = Dune.get_test_modules sample_dune_describe in
  (* Note: Based on the implementation, it looks for test_ prefix in names *)
  Alcotest.(check (list string))
    "test modules" []
    (List.sort String.compare modules)

let test_get_executable_info () =
  let modules = Dune.get_executable_info sample_dune_describe in
  Alcotest.(check (list string))
    "executable modules" [ "Main" ]
    (List.sort String.compare modules)

let test_get_project_files () =
  (* Create a simpler sexp for file extraction test *)
  let files_sexp =
    Parsexp.Single.parse_string_exn
      {|
(library
  ((name mylib)
   (local true)
   (modules
    ((impl (_build/default/lib/parser.ml))
     (intf (_build/default/lib/parser.mli))
     (impl (_build/default/lib/lexer.ml))))))|}
  in
  let files = Dune.get_project_files files_sexp in
  Alcotest.(check (list string))
    "project files"
    [ "lib/lexer.ml"; "lib/parser.ml"; "lib/parser.mli" ]
    (List.sort String.compare files)

let test_is_executable () =
  (* Test that Main module is recognized as executable *)
  Alcotest.(check bool)
    "main.ml is executable" true
    (Dune.is_executable sample_dune_describe "main.ml");
  (* Test that Parser module is not recognized as executable *)
  Alcotest.(check bool)
    "parser.ml is not executable" false
    (Dune.is_executable sample_dune_describe "parser.ml")

let suite =
  [
    ( "dune",
      [
        Alcotest.test_case "get library modules" `Quick test_get_lib_modules;
        Alcotest.test_case "get test modules" `Quick test_get_test_modules;
        Alcotest.test_case "get executable info" `Quick test_get_executable_info;
        Alcotest.test_case "get project files" `Quick test_get_project_files;
        Alcotest.test_case "is executable" `Quick test_is_executable;
      ] );
  ]
