open Merlint

(* Test the complete rules system with real OCaml code *)

let test_analyze_simple_file () =
  (* Create a temporary file with issues *)
  let temp_file = Filename.temp_file "merlint_test" ".ml" in
  let oc = open_out temp_file in
  output_string oc "let test_obj_magic x = Obj.magic x\n";
  close_out oc;

  let config = Config.default in
  match Merlin_interface.analyze_file config temp_file with
  | Ok issues ->
      let has_obj_magic =
        List.exists
          (function Issue.No_obj_magic _ -> true | _ -> false)
          issues
      in
      Alcotest.check Alcotest.bool "detects Obj.magic" true has_obj_magic;
      Sys.remove temp_file
  | Error msg ->
      Sys.remove temp_file;
      Alcotest.fail ("Analysis failed: " ^ msg)

let no_issues_clean_code () =
  (* Create a temporary file without issues *)
  let temp_file = Filename.temp_file "merlint_test" ".ml" in
  let oc = open_out temp_file in
  output_string oc "let add x y = x + y\n";
  close_out oc;

  let config = Config.default in
  match Merlin_interface.analyze_file config temp_file with
  | Ok issues ->
      let violation_count = List.length issues in
      (* Should only have format issues (missing .mli, .ocamlformat) *)
      Alcotest.check Alcotest.bool "has few issues" (violation_count <= 2)
        true;
      Sys.remove temp_file
  | Error msg ->
      Sys.remove temp_file;
      Alcotest.fail ("Analysis failed: " ^ msg)

let tests =
  [
    Alcotest.test_case "analyze_with_issues" `Quick test_analyze_simple_file;
    Alcotest.test_case "analyze_clean_code" `Quick
      no_issues_clean_code;
  ]

let suite = [ ("rules_integration", tests) ]
