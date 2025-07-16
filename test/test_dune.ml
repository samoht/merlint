open Merlint

(* Sample dune describe output for testing *)
let sample_dune_describe =
  Parsexp.Single.parse_string_exn
    {|
((root /home/user/project)
 (build_context
  ((executables
    ((names (main test_lib))
     (modules
      ((impl ((obj_name Main)))
       (impl ((obj_name Test_lib)))))))
   (library
    ((name mylib)
     (local true)
     (modules
      ((impl ((obj_name Parser)))
       (impl ((obj_name Lexer)))
       (intf ((obj_name Parser)))))))
   (test
    ((names (test_parser test_lexer))
     (modules
      ((impl ((obj_name Test_parser)))
       (impl ((obj_name Test_lexer))))))))))|}

let test_get_lib_modules () =
  let modules = Dune.get_lib_modules sample_dune_describe in
  Alcotest.(check (list string))
    "library modules" [ "Parser"; "Lexer" ]
    (List.sort String.compare modules)

let test_get_test_modules () =
  let modules = Dune.get_test_modules sample_dune_describe in
  (* Note: Based on the implementation, it looks for test_ prefix in names *)
  Alcotest.(check (list string))
    "test modules"
    [ "test_parser"; "test_lexer" ]
    (List.sort String.compare modules)

let test_get_executable_info () =
  let modules = Dune.get_executable_info sample_dune_describe in
  Alcotest.(check (list string))
    "executable modules" [ "Main"; "Test_lib" ]
    (List.sort String.compare modules)

let test_get_project_files () =
  (* Create a simpler sexp for file extraction test *)
  let files_sexp =
    Parsexp.Single.parse_string_exn
      {|
((build_context
  ((library
    ((name mylib)
     (local true)
     (modules
      ((impl ((obj_name Parser) (source parser.ml)))
       (intf ((obj_name Parser) (source parser.mli)))
       (impl ((obj_name Lexer) (source lexer.ml)))))))))|}
  in
  let files = Dune.get_project_files files_sexp in
  Alcotest.(check (list string))
    "project files"
    [ "lexer.ml"; "parser.ml"; "parser.mli" ]
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
    ( "dune parsing",
      [
        Alcotest.test_case "get library modules" `Quick test_get_lib_modules;
        Alcotest.test_case "get test modules" `Quick test_get_test_modules;
        Alcotest.test_case "get executable info" `Quick test_get_executable_info;
        Alcotest.test_case "get project files" `Quick test_get_project_files;
        Alcotest.test_case "is executable" `Quick test_is_executable;
      ] );
  ]
