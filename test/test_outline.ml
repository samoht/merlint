(** Tests for Outline module *)

open Merlint.Outline

(* Helper to create test items *)
let item ?(type_string = None) ?(deprecated = false) ?(children = []) ~name
    ~kind () =
  {
    Merlin.name;
    kind;
    type_ = lazy (Option.bind type_string Merlin.parse_core_type);
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
    [ item ~name:"foo" ~kind:Value (); item ~name:"bar" ~kind:Type () ]
  in
  let result = flatten items in
  Alcotest.(check int) "two items" 2 (List.length result)

let test_flatten_with_children () =
  let child = item ~name:"inner" ~kind:Value () in
  let parent = item ~name:"Outer" ~kind:Module ~children:[ child ] () in
  let result = flatten [ parent ] in
  Alcotest.(check int) "parent and child" 2 (List.length result)

let test_get_values () =
  let items =
    [
      item ~name:"foo" ~kind:Value ~type_string:(Some "int") ();
      item ~name:"Bar" ~kind:Type ();
      item ~name:"baz" ~kind:Value ~type_string:(Some "string") ();
    ]
  in

  let result = values items in
  Alcotest.(check int) "two values" 2 (List.length result);
  Alcotest.(check string) "first value" "foo" (List.hd result).name;
  Alcotest.(check string) "second value" "baz" (List.nth result 1).name

let test_find_by_name () =
  let items =
    [
      item ~name:"foo" ~kind:Value ~type_string:(Some "int") ();
      item ~name:"Bar" ~kind:Type ();
    ]
  in

  let found = by_name "foo" items in
  Alcotest.(check bool) "found foo" true (found <> None);
  Alcotest.(check string) "correct item" "foo" (Option.get found).name;

  let not_found = by_name "baz" items in
  Alcotest.(check bool) "not found baz" true (not_found = None)

let test_find_nested () =
  let child = item ~name:"nested" ~kind:Value () in
  let parent = item ~name:"M" ~kind:Module ~children:[ child ] () in
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
      let item = item ~name ~kind () in
      Alcotest.(check string) (Fmt.str "%s kind" name) name item.name)
    kinds

let test_is_function_type () =
  let mk ts = item ~name:"x" ~kind:Value ~type_string:(Some ts) () in
  Alcotest.(check bool)
    "arrow is function" true
    (is_function_type (mk "int -> int"));
  Alcotest.(check bool)
    "simple not function" false
    (is_function_type (mk "int"));
  Alcotest.(check bool)
    "multi arrow is function" true
    (is_function_type (mk "int -> int -> int"))

let int_constr (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "int"; _ }, []) -> true
  | _ -> false

let test_count_parameters () =
  let mk ts = item ~name:"x" ~kind:Value ~type_string:(Some ts) () in
  Alcotest.(check int)
    "one int" 1
    (count_parameters (mk "int -> string") ~matches:int_constr);
  Alcotest.(check int)
    "two ints" 2
    (count_parameters (mk "int -> int -> string") ~matches:int_constr);
  Alcotest.(check int)
    "no match" 0
    (count_parameters (mk "int -> string") ~matches:(fun ct ->
         match ct.ptyp_desc with
         | Ptyp_constr ({ txt = Lident "bool"; _ }, []) -> true
         | _ -> false))

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
    Alcotest.test_case "count_parameters" `Quick test_count_parameters;
  ]

let suite = ("outline", tests)
