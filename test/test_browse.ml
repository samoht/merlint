(** Tests for Browse module *)

open Merlint.Browse

let test_parse_value_binding () =
  (* Test case with a simple value binding *)
  let json =
    `List
      [
        `Assoc
          [
            ("kind", `String "structure");
            ( "children",
              `List
                [
                  `Assoc
                    [
                      ("kind", `String "value_binding");
                      ("filename", `String "test.ml");
                      ("start", `Assoc [ ("line", `Int 1); ("col", `Int 0) ]);
                      ("end", `Assoc [ ("line", `Int 3); ("col", `Int 10) ]);
                      ( "children",
                        `List
                          [
                            `Assoc
                              [
                                ( "kind",
                                  `String
                                    "pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
                                    \  Tpat_var \"foo/123\"" );
                              ];
                          ] );
                    ];
                ] );
          ];
      ]
  in

  let result = of_json json in
  let bindings = get_value_bindings result in
  Alcotest.(check int) "one binding" 1 (List.length bindings);

  let binding = List.hd bindings in
  Alcotest.(check (option string)) "name" (Some "foo") binding.name;
  Alcotest.(check bool) "has location" true (binding.location <> None)

let test_pattern_matching_detection () =
  (* Test case with pattern matching *)
  let json =
    `List
      [
        `Assoc
          [
            ("kind", `String "value_binding");
            ( "children",
              `List
                [
                  `Assoc [ ("kind", `String "case") ];
                  `Assoc [ ("kind", `String "case") ];
                ] );
          ];
      ]
  in

  let result = of_json json in
  match get_value_bindings result with
  | [ binding ] ->
      Alcotest.(check bool)
        "has pattern match" true binding.pattern_info.has_pattern_match;
      Alcotest.(check int) "case count" 2 binding.pattern_info.case_count
  | _ -> Alcotest.fail "Expected one binding"

let test_no_pattern_matching () =
  (* Test case without pattern matching *)
  let json =
    `List
      [
        `Assoc
          [
            ("kind", `String "value_binding");
            ("children", `List [ `Assoc [ ("kind", `String "expression") ] ]);
          ];
      ]
  in

  let result = of_json json in
  match get_value_bindings result with
  | [ binding ] ->
      Alcotest.(check bool)
        "no pattern match" false binding.pattern_info.has_pattern_match;
      Alcotest.(check int) "no cases" 0 binding.pattern_info.case_count
  | _ -> Alcotest.fail "Expected one binding"

let tests =
  [
    Alcotest.test_case "parse_value_binding" `Quick test_parse_value_binding;
    Alcotest.test_case "pattern_matching_detection" `Quick
      test_pattern_matching_detection;
    Alcotest.test_case "no_pattern_matching" `Quick test_no_pattern_matching;
  ]

let suite = [ ("browse", tests) ]
