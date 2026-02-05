(** Tests for Outline module *)

open Merlint.Outline

(* Helper to create test items *)
let make_item ?(type_sig = None) ?(deprecated = false) ?(children = []) ~name
    ~kind () =
  {
    Merlin.name;
    kind;
    type_sig;
    deprecated;
    location =
      {
        file = "test.ml";
        start = { line = 1; col = 0 };
        end_ = { line = 1; col = 10 };
      };
    children;
  }

let test_flatten_empty () =
  let result = flatten [] in
  Alcotest.(check int) "empty outline" 0 (List.length result)

let test_flatten_simple () =
  let items =
    [
      make_item ~name:"foo" ~kind:Value (); make_item ~name:"bar" ~kind:Type ();
    ]
  in
  let result = flatten items in
  Alcotest.(check int) "two items" 2 (List.length result)

let test_flatten_with_children () =
  let child = make_item ~name:"inner" ~kind:Value () in
  let parent = make_item ~name:"Outer" ~kind:Module ~children:[ child ] () in
  let result = flatten [ parent ] in
  Alcotest.(check int) "parent and child" 2 (List.length result)

let test_get_values () =
  let items =
    [
      make_item ~name:"foo" ~kind:Value ~type_sig:(Some "int") ();
      make_item ~name:"Bar" ~kind:Type ();
      make_item ~name:"baz" ~kind:Value ~type_sig:(Some "string") ();
    ]
  in

  let result = values items in
  Alcotest.(check int) "two values" 2 (List.length result);
  Alcotest.(check string) "first value" "foo" (List.hd result).name;
  Alcotest.(check string) "second value" "baz" (List.nth result 1).name

let test_find_by_name () =
  let items =
    [
      make_item ~name:"foo" ~kind:Value ~type_sig:(Some "int") ();
      make_item ~name:"Bar" ~kind:Type ();
    ]
  in

  let found = by_name "foo" items in
  Alcotest.(check bool) "found foo" true (found <> None);
  Alcotest.(check string) "correct item" "foo" (Option.get found).name;

  let not_found = by_name "baz" items in
  Alcotest.(check bool) "not found baz" true (not_found = None)

let test_find_nested () =
  let child = make_item ~name:"nested" ~kind:Value () in
  let parent = make_item ~name:"M" ~kind:Module ~children:[ child ] () in
  let found = by_name "nested" [ parent ] in
  Alcotest.(check bool) "found nested" true (found <> None);
  Alcotest.(check string) "correct name" "nested" (Option.get found).name

let test_all_kinds () =
  let kinds =
    [
      (Value, "value");
      (Type, "type");
      (Module, "module");
      (Module_type, "module_type");
      (Class, "class");
      (Class_type, "class_type");
      (Constructor, "constructor");
      (Exception, "exception");
      (Field, "field");
      (Method, "method");
      (Label, "label");
    ]
  in
  List.iter
    (fun (kind, name) ->
      let item = make_item ~name ~kind () in
      Alcotest.(check string) (Fmt.str "%s kind" name) name item.name)
    kinds

let test_is_function_type () =
  Alcotest.(check bool) "arrow is function" true (is_function_type "int -> int");
  Alcotest.(check bool) "simple not function" false (is_function_type "int");
  Alcotest.(check bool)
    "multi arrow is function" true
    (is_function_type "int -> int -> int")

let test_extract_return_type () =
  Alcotest.(check string)
    "simple return" "string"
    (extract_return_type "int -> string");
  Alcotest.(check string)
    "multi-arg return" "bool"
    (extract_return_type "int -> string -> bool");
  Alcotest.(check string) "no arrow" "int" (extract_return_type "int")

let test_count_parameters () =
  Alcotest.(check int) "one int" 1 (count_parameters "int -> string" "int");
  Alcotest.(check int)
    "two ints" 2
    (count_parameters "int -> int -> string" "int");
  Alcotest.(check int) "no match" 0 (count_parameters "int -> string" "bool")

let tests =
  [
    Alcotest.test_case "flatten_empty" `Quick test_flatten_empty;
    Alcotest.test_case "flatten_simple" `Quick test_flatten_simple;
    Alcotest.test_case "flatten_with_children" `Quick test_flatten_with_children;
    Alcotest.test_case "get_values" `Quick test_get_values;
    Alcotest.test_case "find_by_name" `Quick test_find_by_name;
    Alcotest.test_case "find_nested" `Quick test_find_nested;
    Alcotest.test_case "all_kinds" `Quick test_all_kinds;
    Alcotest.test_case "is_function_type" `Quick test_is_function_type;
    Alcotest.test_case "extract_return_type" `Quick test_extract_return_type;
    Alcotest.test_case "count_parameters" `Quick test_count_parameters;
  ]

let suite = ("outline", tests)
