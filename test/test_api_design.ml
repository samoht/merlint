open Alcotest
open Merlint

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
      let actual = Api_design.count_bool_params sig_str in
      check int (Printf.sprintf "bool count in '%s'" sig_str) expected actual)
    test_cases

let create_temp_file content =
  let temp_file = Filename.temp_file "test_api_design" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

let test_boolean_blindness () =
  let source =
    {|
let create_window visible resizable fullscreen =
  if visible && resizable && fullscreen then
    "all options"
  else
    "some options"

let setup_app debug verbose =
  if debug && verbose then "debug verbose" else "normal"
  
let single_bool visible = if visible then "show" else "hide"
|}
  in

  let temp_file = create_temp_file source in
  match Merlin.analyze_file temp_file with
  | { outline = Ok outline; typedtree = Ok typedtree; _ } ->
      let issues =
        Api_design.check ~filename:temp_file ~outline:(Some outline) typedtree
      in
      Sys.remove temp_file;

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
  | _ ->
      Sys.remove temp_file;
      fail "Failed to analyze file"

let tests =
  [
    test_case "count bool params" `Quick test_count_bool_params;
    test_case "detect boolean blindness" `Quick test_boolean_blindness;
  ]

let suite = ("Api_design", tests)
