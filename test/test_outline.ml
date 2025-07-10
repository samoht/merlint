(** Tests for Outline module *)

open Merlint.Outline

let test_parse_empty () =
  let json = `List [] in
  let result = of_json json in
  Alcotest.(check int) "empty outline" 0 (List.length result)

let test_parse_simple () =
  let json =
    `List
      [
        `Assoc
          [
            ("name", `String "foo");
            ("kind", `String "Value");
            ("type", `String "int -> int");
            ( "location",
              `Assoc
                [
                  ("start", `Assoc [ ("line", `Int 1); ("col", `Int 0) ]);
                  ("end", `Assoc [ ("line", `Int 1); ("col", `Int 10) ]);
                ] );
          ];
        `Assoc [ ("name", `String "Bar"); ("kind", `String "Type") ];
      ]
  in

  let result = of_json json in
  Alcotest.(check int) "two items" 2 (List.length result);

  let first = List.hd result in
  Alcotest.(check string) "first name" "foo" first.name;
  Alcotest.(check bool) "first is value" true (first.kind = Value);
  Alcotest.(check (option string))
    "first type" (Some "int -> int") first.type_sig;
  Alcotest.(check bool) "first has range" true (first.range <> None);

  let second = List.nth result 1 in
  Alcotest.(check string) "second name" "Bar" second.name;
  Alcotest.(check bool) "second is type" true (second.kind = Type);
  Alcotest.(check (option string)) "second no type" None second.type_sig

let test_get_values () =
  let items =
    [
      { name = "foo"; kind = Value; type_sig = Some "int"; range = None };
      { name = "Bar"; kind = Type; type_sig = None; range = None };
      { name = "baz"; kind = Value; type_sig = Some "string"; range = None };
    ]
  in

  let values = get_values items in
  Alcotest.(check int) "two values" 2 (List.length values);
  Alcotest.(check string) "first value" "foo" (List.hd values).name;
  Alcotest.(check string) "second value" "baz" (List.nth values 1).name

let test_find_by_name () =
  let items =
    [
      { name = "foo"; kind = Value; type_sig = Some "int"; range = None };
      { name = "Bar"; kind = Type; type_sig = None; range = None };
    ]
  in

  let found = find_by_name "foo" items in
  Alcotest.(check bool) "found foo" true (found <> None);
  Alcotest.(check string) "correct item" "foo" (Option.get found).name;

  let not_found = find_by_name "baz" items in
  Alcotest.(check bool) "not found baz" true (not_found = None)

let test_parse_kinds () =
  let json =
    `List
      [
        `Assoc [ ("name", `String "m"); ("kind", `String "Module") ];
        `Assoc [ ("name", `String "c"); ("kind", `String "Class") ];
        `Assoc [ ("name", `String "e"); ("kind", `String "Exn") ];
        `Assoc [ ("name", `String "C"); ("kind", `String "Constructor") ];
        `Assoc [ ("name", `String "f"); ("kind", `String "Field") ];
        `Assoc [ ("name", `String "meth"); ("kind", `String "Method") ];
        `Assoc [ ("name", `String "x"); ("kind", `String "Unknown") ];
      ]
  in

  let items = of_json json in
  let kinds = List.map (fun item -> item.kind) items in

  Alcotest.(check bool) "has module" true (List.mem Module kinds);
  Alcotest.(check bool) "has class" true (List.mem Class kinds);
  Alcotest.(check bool) "has exception" true (List.mem Exception kinds);
  Alcotest.(check bool) "has constructor" true (List.mem Constructor kinds);
  Alcotest.(check bool) "has field" true (List.mem Field kinds);
  Alcotest.(check bool) "has method" true (List.mem Method kinds);
  Alcotest.(check bool)
    "has other" true
    (List.exists (function Other _ -> true | _ -> false) kinds)

let tests =
  [
    Alcotest.test_case "parse_empty" `Quick test_parse_empty;
    Alcotest.test_case "parse_simple" `Quick test_parse_simple;
    Alcotest.test_case "get_values" `Quick test_get_values;
    Alcotest.test_case "find_by_name" `Quick test_find_by_name;
    Alcotest.test_case "parse_kinds" `Quick test_parse_kinds;
  ]

let suite = [ ("outline", tests) ]
