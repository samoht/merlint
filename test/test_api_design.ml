open Alcotest
open Merlint

(* Helper function to count bool params - copied from E350 for testing *)
let count_bool_params type_sig =
  (* Count occurrences of "bool" in the signature, excluding the return type *)
  let parts = String.split_on_char '>' type_sig in
  let param_part =
    match List.rev parts with
    | [] -> type_sig
    | _return_type :: rest -> String.concat ">" (List.rev rest)
  in
  (* Count "bool" occurrences in parameter part *)
  let rec count acc pos str =
    match String.index_from_opt str pos 'b' with
    | None -> acc
    | Some idx ->
        if idx + 4 <= String.length str && String.sub str idx 4 = "bool" then
          count (acc + 1) (idx + 4) str
        else count acc (idx + 1) str
  in
  count 0 0 param_part

let test_count_bool_params () =
  let test_cases =
    [
      ("bool -> bool -> unit", 2);
      ("int -> bool -> string", 1);
      ("bool -> int -> bool -> unit", 2);
      ("unit -> unit", 0);
      ("string -> string", 0);
      ("?color:bool -> ?verbose:bool -> unit -> unit", 2);
    ]
  in

  List.iter
    (fun (sig_str, expected) ->
      let actual = count_bool_params sig_str in
      check int (Fmt.str "bool count in '%s'" sig_str) expected actual)
    test_cases

let test_boolean_blindness () =
  (* Create mock outline data instead of using file I/O *)
  let mock_outline =
    [
      Outline.
        {
          name = "create_window";
          kind = Value;
          type_sig = Some "bool -> bool -> bool -> string";
          range =
            Some
              { start = { line = 2; col = 4 }; end_ = { line = 6; col = 20 } };
        };
      Outline.
        {
          name = "setup_app";
          kind = Value;
          type_sig = Some "bool -> bool -> string";
          range =
            Some
              { start = { line = 8; col = 4 }; end_ = { line = 9; col = 35 } };
        };
      Outline.
        {
          name = "single_bool";
          kind = Value;
          type_sig = Some "bool -> string";
          range =
            Some
              { start = { line = 11; col = 4 }; end_ = { line = 11; col = 55 } };
        };
    ]
  in

  (* Create empty typedtree since api_design doesn't use it *)
  let mock_typedtree =
    Typedtree.
      {
        identifiers = [];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in

  let issues =
    Api_design.check ~filename:"test.ml" ~outline:(Some mock_outline)
      mock_typedtree
  in

  let bool_blindness_issues =
    List.filter
      (fun issue ->
        match issue with Issue.Boolean_blindness _ -> true | _ -> false)
      issues
  in

  check int "number of boolean blindness issues" 2
    (List.length bool_blindness_issues);

  List.iter
    (fun issue ->
      match issue with
      | Issue.Boolean_blindness { function_name; bool_count; _ } ->
          if function_name = "create_window" then
            check int "create_window bool count" 3 bool_count
          else if function_name = "setup_app" then
            check int "setup_app bool count" 2 bool_count
      | _ -> ())
    bool_blindness_issues

let tests =
  [
    test_case "count bool params" `Quick test_count_bool_params;
    test_case "detect boolean blindness" `Quick test_boolean_blindness;
  ]

let suite = ("Api_design", tests)
