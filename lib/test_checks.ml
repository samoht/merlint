(** Test file convention checks

    This module checks that test files follow proper conventions. *)

let is_test_file filename =
  String.ends_with ~suffix:"_test.ml" filename
  || Filename.basename filename = "test.ml"

let has_test_runner content =
  Re.execp (Re.compile (Re.str "Alcotest.run")) content
  || Re.execp (Re.compile (Re.str "OUnit")) content
  || Re.execp (Re.compile (Re.str "QCheck")) content

let exports_suite content =
  (* Check for proper Alcotest suite definition *)
  Re.execp
    (Re.compile
       (Re.seq
          [
            Re.str "let";
            Re.rep1 Re.space;
            Re.str "suite";
            Re.rep Re.space;
            Re.opt
              (Re.seq
                 [
                   Re.str ":";
                   Re.rep Re.space;
                   Re.rep1
                     (Re.alt
                        [
                          Re.alnum;
                          Re.char '_';
                          Re.char '.';
                          Re.char ' ';
                          Re.char '(';
                          Re.char ')';
                          Re.char '*';
                        ]);
                   Re.rep Re.space;
                 ]);
            Re.str "=";
          ]))
    content

let get_module_name filename =
  let base_name = Filename.basename filename |> Filename.chop_extension in
  (* Remove _test suffix if present *)
  if String.ends_with ~suffix:"_test" base_name then
    String.sub base_name 0 (String.length base_name - 5)
  else base_name

let exports_module_name content module_base =
  Re.execp
    (Re.compile
       (Re.seq
          [
            Re.str "Alcotest.run";
            Re.rep1 Re.space;
            Re.str "\"";
            Re.str module_base;
            Re.str "\"";
          ]))
    content

(** Check if a test file properly exports suite instead of using module name
    directly.

    Good pattern (what we want): ```ocaml (* test_foo.ml *) let test_basic () =
    ... let test_advanced () = ...

    let suite =
    [ ("basic", [ Alcotest.test_case "test1" `Quick test_basic ]); ("advanced",
     [ Alcotest.test_case "test2" `Quick test_advanced ]); ]

    let () = Alcotest.run "Test suite description" suite ```

    Bad pattern (what we flag): ```ocaml (* test_foo.ml *) let test_basic () =
    ...

    let () = Alcotest.run "test_foo"
    [  (* Using module name instead of suite *) ("basic", [ Alcotest.test_case
     "test1" `Quick test_basic ]); ] ``` *)
let check_test_file_exports filename content =
  if not (is_test_file filename) then []
  else if not (has_test_runner content) then []
  else
    let module_base = get_module_name filename in
    (* Issue if using module name instead of exporting suite *)
    if exports_module_name content module_base && not (exports_suite content)
    then
      [
        Issue.Test_exports_module_name
          {
            filename;
            location = Location.create ~file:filename ~line:1 ~col:0;
            module_name = module_base;
          };
      ]
    else []

(** Check if a test .mli file exports only suite with correct type *)
let check_test_mli_file filename content =
  if
    not
      (String.ends_with ~suffix:"_test.mli" filename
      || Filename.basename filename = "test.mli")
  then []
  else
    (* Check if it has the correct suite signature *)
    let has_correct_suite =
      Re.execp
        (Re.compile
           (Re.seq
              [
                Re.str "val";
                Re.rep1 Re.space;
                Re.str "suite";
                Re.rep Re.space;
                Re.str ":";
                Re.rep Re.space;
                Re.str "(string * unit Alcotest.test_case list) list";
              ]))
        content
    in
    (* Check if it exports anything else (simplified check) *)
    let lines = String.split_on_char '\n' content in
    let val_lines =
      List.filter
        (fun line ->
          let trimmed = String.trim line in
          String.starts_with ~prefix:"val " trimmed
          && not (String.starts_with ~prefix:"val suite" trimmed))
        lines
    in
    if (not has_correct_suite) || val_lines <> [] then
      [
        Issue.Test_exports_module_name
          {
            filename;
            location = Location.create ~file:filename ~line:1 ~col:0;
            module_name = "incorrect interface";
          };
      ]
    else []

(** Check all test files in the list *)
let check files =
  List.concat_map
    (fun filename ->
      try
        let content = In_channel.with_open_text filename In_channel.input_all in
        if String.ends_with ~suffix:".ml" filename then
          check_test_file_exports filename content
        else if String.ends_with ~suffix:".mli" filename then
          check_test_mli_file filename content
        else []
      with _ -> [])
    files
