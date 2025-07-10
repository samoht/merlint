(** Tests for the Sexp module *)

open Merlint.Sexp

let test_atom_parsing () =
  match parse_string "Texp_match" with
  | Ok (Atom "Texp_match") -> ()
  | _ -> failwith "Failed to parse atom"

let test_list_parsing () =
  match parse_string "(Texp_match case1 case2)" with
  | Ok (List [ Atom "Texp_match"; Atom "case1"; Atom "case2" ]) -> ()
  | _ -> failwith "Failed to parse list"

let test_nested_parsing () =
  match parse_string "(Texp_match (case1 arg1) (case2 arg2))" with
  | Ok
      (List
         [
           Atom "Texp_match";
           List [ Atom "case1"; Atom "arg1" ];
           List [ Atom "case2"; Atom "arg2" ];
         ]) ->
      ()
  | _ -> failwith "Failed to parse nested list"

let test_pattern_match_detection () =
  let atom_match = Atom "Texp_match" in
  let list_match = List [ Atom "Texp_match"; Atom "case1" ] in
  let non_match = Atom "Texp_let" in

  assert (is_pattern_match atom_match);
  assert (is_pattern_match list_match);
  assert (not (is_pattern_match non_match))

let test_conditional_detection () =
  let atom_if = Atom "Texp_ifthenelse" in
  let list_if =
    List [ Atom "Texp_ifthenelse"; Atom "cond"; Atom "then_branch" ]
  in
  let non_if = Atom "Texp_let" in

  assert (is_conditional atom_if);
  assert (is_conditional list_if);
  assert (not (is_conditional non_if))

let test_loop_detection () =
  let atom_while = Atom "Texp_while" in
  let list_for = List [ Atom "Texp_for"; Atom "i"; Atom "start"; Atom "end" ] in
  let non_loop = Atom "Texp_let" in

  assert (is_loop atom_while);
  assert (is_loop list_for);
  assert (not (is_loop non_loop))

let test_complexity_detection () =
  let match_expr = Atom "Texp_match" in
  let if_expr = Atom "Texp_ifthenelse" in
  let while_expr = Atom "Texp_while" in
  let try_expr = Atom "Texp_try" in
  let let_expr = Atom "Texp_let" in

  assert (adds_complexity match_expr);
  assert (adds_complexity if_expr);
  assert (adds_complexity while_expr);
  assert (adds_complexity try_expr);
  assert (not (adds_complexity let_expr))

let test_texp_name_extraction () =
  let match_atom = Atom "Texp_match" in
  let match_list = List [ Atom "Texp_ifthenelse"; Atom "cond" ] in
  let non_texp = Atom "variable" in

  assert (get_texp_name match_atom = Some "Texp_match");
  assert (get_texp_name match_list = Some "Texp_ifthenelse");
  assert (get_texp_name non_texp = None)

let test_error_handling () =
  match parse_string "(unclosed list" with
  | Error _ -> ()
  | Ok _ -> failwith "Should have failed on unclosed list"

let test_empty_input () =
  match parse_string "" with
  | Error _ -> ()
  | Ok _ -> failwith "Should have failed on empty input"

let test_to_string () =
  let atom = Atom "Texp_match" in
  let list = List [ Atom "Texp_match"; Atom "case1" ] in

  assert (to_string atom = "Texp_match");
  assert (to_string list = "(Texp_match case1)")

let run_tests () =
  test_atom_parsing ();
  test_list_parsing ();
  test_nested_parsing ();
  test_pattern_match_detection ();
  test_conditional_detection ();
  test_loop_detection ();
  test_complexity_detection ();
  test_texp_name_extraction ();
  test_error_handling ();
  test_empty_input ();
  test_to_string ();
  print_endline "All sexp tests passed!"

let () = run_tests ()
