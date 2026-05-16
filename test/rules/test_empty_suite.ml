(* Adversarial tests for [Merlint.Empty_suite]. *)

open Merlint

let parse src =
  match Ast.parse_structure ~filename:"scratch.ml" src with
  | Some structure -> structure
  | None -> Alcotest.fail "parse failed"

let test_is_empty_list_bare () =
  let s = parse {|let _ = []|} in
  match s with
  | [ { pstr_desc = Pstr_value (_, [ { pvb_expr; _ } ]); _ } ] ->
      Alcotest.(check bool)
        "bare [] is empty" true
        (Empty_suite.is_empty_list pvb_expr)
  | _ -> Alcotest.fail "unexpected structure"

let test_is_empty_list_open () =
  let s = parse {|let _ = List.[]|} in
  match s with
  | [ { pstr_desc = Pstr_value (_, [ { pvb_expr; _ } ]); _ } ] ->
      Alcotest.(check bool)
        "List.[] is empty (under Pexp_open)" true
        (Empty_suite.is_empty_list pvb_expr)
  | _ -> Alcotest.fail "unexpected structure"

let test_is_empty_list_nonempty () =
  let s = parse {|let _ = [ 1; 2 ]|} in
  match s with
  | [ { pstr_desc = Pstr_value (_, [ { pvb_expr; _ } ]); _ } ] ->
      Alcotest.(check bool)
        "non-empty list rejected" false
        (Empty_suite.is_empty_list pvb_expr)
  | _ -> Alcotest.fail "unexpected structure"

let test_find_empty_suite_present () =
  let s = parse {|let suite = ("foo", [])|} in
  Alcotest.(check bool)
    "find_empty_suite returns Some" true
    (Empty_suite.find s <> None)

let test_find_empty_suite_nonempty () =
  let s = parse {|let suite = ("foo", [ x ])|} in
  Alcotest.(check bool)
    "non-empty suite returns None" true
    (Empty_suite.find s = None)

let test_find_empty_suite_absent () =
  let s = parse {|let other = ("foo", [])|} in
  Alcotest.(check bool)
    "binding not named suite -> None" true
    (Empty_suite.find s = None)

let test_find_alcobar_open () =
  (* Spec: [Alcobar.[]] / [List.[]] is still the empty list and must be
     detected -- this is the fuzz-suite shape. *)
  let s = parse {|let suite = ("p", Alcobar.[])|} in
  Alcotest.(check bool)
    "Alcobar.[] under Pexp_open is detected" true
    (Empty_suite.find s <> None)

let test_find_wrong_shape () =
  (* [let suite = "foo"] -- not a tuple at all. *)
  let s = parse {|let suite = "foo"|} in
  Alcotest.(check bool)
    "non-tuple suite shape -> None" true
    (Empty_suite.find s = None)

let test_find_extra_bindings () =
  (* Multiple [let suite = ...] bindings (impossible in real code but
     legal syntax). The walker must still match the first empty one. *)
  let s =
    parse {|let suite = ("a", [ x ])
let other = 1
let unrelated = "y"|}
  in
  Alcotest.(check bool)
    "no empty suite in mixed bindings" true
    (Empty_suite.find s = None)

let suite =
  ( "empty_suite",
    [
      Alcotest.test_case "is_empty_list: bare" `Quick test_is_empty_list_bare;
      Alcotest.test_case "is_empty_list: under open" `Quick
        test_is_empty_list_open;
      Alcotest.test_case "is_empty_list: non-empty" `Quick
        test_is_empty_list_nonempty;
      Alcotest.test_case "find_empty_suite: present" `Quick
        test_find_empty_suite_present;
      Alcotest.test_case "find_empty_suite: non-empty" `Quick
        test_find_empty_suite_nonempty;
      Alcotest.test_case "find_empty_suite: absent" `Quick
        test_find_empty_suite_absent;
      Alcotest.test_case "find_empty_suite: Alcobar.[]" `Quick
        test_find_alcobar_open;
      Alcotest.test_case "find_empty_suite: wrong shape" `Quick
        test_find_wrong_shape;
      Alcotest.test_case "find_empty_suite: mixed bindings" `Quick
        test_find_extra_bindings;
    ] )
