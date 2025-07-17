open Merlint

let test_empty () =
  let c = E001.Complexity.empty in
  Alcotest.(check int) "total" 0 c.total;
  Alcotest.(check int) "if_then_else" 0 c.if_then_else;
  Alcotest.(check int) "match_cases" 0 c.match_cases;
  Alcotest.(check int) "try_handlers" 0 c.try_handlers;
  Alcotest.(check int) "boolean_operators" 0 c.boolean_operators

let test_if_then_else () =
  (* Simple if-then-else expression *)
  let expr =
    Ast.If_then_else
      {
        cond = Ast.Constant "true";
        then_expr = Ast.Constant "1";
        else_expr = Some (Ast.Constant "2");
      }
  in
  let c = E001.Complexity.analyze_expr expr in
  Alcotest.(check int) "if_then_else count" 1 c.if_then_else;
  Alcotest.(check int) "total" 1 c.total;
  Alcotest.(check int) "cyclomatic complexity" 2 (E001.Complexity.calculate c)

let test_nested_if () =
  (* Nested if-then-else expressions *)
  let inner_if =
    Ast.If_then_else
      {
        cond = Ast.Constant "true";
        then_expr = Ast.Constant "1";
        else_expr = Some (Ast.Constant "2");
      }
  in
  let expr =
    Ast.If_then_else
      {
        cond = Ast.Constant "true";
        then_expr = inner_if;
        else_expr = Some (Ast.Constant "3");
      }
  in
  let c = E001.Complexity.analyze_expr expr in
  Alcotest.(check int) "if_then_else count" 2 c.if_then_else;
  Alcotest.(check int) "total" 2 c.total;
  Alcotest.(check int) "cyclomatic complexity" 3 (E001.Complexity.calculate c)

let test_match_expression () =
  (* Match with 3 cases *)
  let expr = Ast.Match { expr = Ast.Ident "x"; cases = 3 } in
  let c = E001.Complexity.analyze_expr expr in
  Alcotest.(check int) "match_cases count" 2 c.match_cases;
  (* 3 cases - 1 *)
  Alcotest.(check int) "total" 2 c.total;
  Alcotest.(check int) "cyclomatic complexity" 3 (E001.Complexity.calculate c)

let test_try_expression () =
  (* Try with 2 exception handlers *)
  let expr = Ast.Try { expr = Ast.Constant "risky"; handlers = 2 } in
  let c = E001.Complexity.analyze_expr expr in
  Alcotest.(check int) "try_handlers count" 2 c.try_handlers;
  Alcotest.(check int) "total" 2 c.total;
  Alcotest.(check int) "cyclomatic complexity" 3 (E001.Complexity.calculate c)

let test_boolean_operators () =
  (* Expression with && operator *)
  let expr =
    Ast.Apply
      {
        func = Ast.Ident "Stdlib.&&";
        args = [ Ast.Constant "true"; Ast.Constant "false" ];
      }
  in
  let c = E001.Complexity.analyze_expr expr in
  Alcotest.(check int) "boolean_operators count" 1 c.boolean_operators;
  Alcotest.(check int) "total" 1 c.total;
  Alcotest.(check int) "cyclomatic complexity" 2 (E001.Complexity.calculate c)

let test_find_function_binding () =
  (* Typedtree structure with a function binding *)
  let json =
    `Assoc
      [
        ( "str_items",
          `List
            [
              `Assoc
                [
                  ( "str_desc",
                    `List
                      [
                        `String "Tstr_value";
                        `Null;
                        `List
                          [
                            `Assoc
                              [
                                ( "vb_pat",
                                  `Assoc
                                    [
                                      ( "pat_desc",
                                        `List
                                          [
                                            `String "Tpat_var";
                                            `String "test_func";
                                          ] );
                                    ] );
                                ( "vb_expr",
                                  `Assoc
                                    [
                                      ( "exp_desc",
                                        `List
                                          [
                                            `String "Texp_constant";
                                            `String "42";
                                          ] );
                                    ] );
                              ];
                          ];
                      ] );
                ];
            ] );
      ]
  in
  match Ast.find_function_binding "test_func" json with
  | Some expr ->
      Alcotest.(check bool)
        "found function" true
        (match expr with Ast.Constant _ -> true | _ -> false)
  | None -> Alcotest.fail "Should find function binding"

let test_analyze_function () =
  (* Typedtree with a function containing if-then-else *)
  let json =
    `Assoc
      [
        ( "str_items",
          `List
            [
              `Assoc
                [
                  ( "str_desc",
                    `List
                      [
                        `String "Tstr_value";
                        `Null;
                        `List
                          [
                            `Assoc
                              [
                                ( "vb_pat",
                                  `Assoc
                                    [
                                      ( "pat_desc",
                                        `List
                                          [
                                            `String "Tpat_var"; `String "check";
                                          ] );
                                    ] );
                                ( "vb_expr",
                                  `Assoc
                                    [
                                      ( "exp_desc",
                                        `List
                                          [
                                            `String "Texp_ifthenelse";
                                            `Assoc
                                              [
                                                ( "exp_desc",
                                                  `List
                                                    [
                                                      `String "Texp_constant";
                                                      `String "true";
                                                    ] );
                                              ];
                                            `Assoc
                                              [
                                                ( "exp_desc",
                                                  `List
                                                    [
                                                      `String "Texp_constant";
                                                      `String "1";
                                                    ] );
                                              ];
                                            `Assoc
                                              [
                                                ( "exp_desc",
                                                  `List
                                                    [
                                                      `String "Texp_constant";
                                                      `String "2";
                                                    ] );
                                              ];
                                          ] );
                                    ] );
                              ];
                          ];
                      ] );
                ];
            ] );
      ]
  in
  match Ast.find_function_binding "check" json with
  | Some expr ->
      let c = E001.Complexity.analyze_expr expr in
      Alcotest.(check int) "if_then_else count" 1 c.if_then_else;
      Alcotest.(check int) "total" 1 c.total;
      Alcotest.(check int)
        "cyclomatic complexity" 2
        (E001.Complexity.calculate c)
  | None -> Alcotest.fail "Should find function binding"

let suite =
  ( "complexity",
    [
      Alcotest.test_case "empty complexity" `Quick test_empty;
      Alcotest.test_case "if-then-else" `Quick test_if_then_else;
      Alcotest.test_case "nested if" `Quick test_nested_if;
      Alcotest.test_case "match expression" `Quick test_match_expression;
      Alcotest.test_case "try expression" `Quick test_try_expression;
      Alcotest.test_case "boolean operators" `Quick test_boolean_operators;
      Alcotest.test_case "find function binding" `Quick
        test_find_function_binding;
      Alcotest.test_case "analyze function" `Quick test_analyze_function;
    ] )
