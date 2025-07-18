(** Tests for AST module *)

open Merlint

let complexity_tests =
  [
    Alcotest.test_case "empty complexity" `Quick (fun () ->
        let c = Ast.Complexity.empty in
        Alcotest.(check int) "total" 0 c.total;
        Alcotest.(check int) "if_then_else" 0 c.if_then_else;
        Alcotest.(check int) "match_cases" 0 c.match_cases;
        Alcotest.(check int) "try_handlers" 0 c.try_handlers;
        Alcotest.(check int) "boolean_operators" 0 c.boolean_operators);
    Alcotest.test_case "if-then-else" `Quick (fun () ->
        let expr =
          Ast.If_then_else
            {
              cond = Ast.Constant "true";
              then_expr = Ast.Constant "1";
              else_expr = Some (Ast.Constant "2");
            }
        in
        let c = Ast.Complexity.analyze_expr expr in
        Alcotest.(check int) "if_then_else count" 1 c.if_then_else;
        Alcotest.(check int) "total" 1 c.total;
        Alcotest.(check int)
          "cyclomatic complexity" 2
          (Ast.Complexity.calculate c));
    Alcotest.test_case "nested if" `Quick (fun () ->
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
        let c = Ast.Complexity.analyze_expr expr in
        Alcotest.(check int) "if_then_else count" 2 c.if_then_else;
        Alcotest.(check int) "total" 2 c.total;
        Alcotest.(check int)
          "cyclomatic complexity" 3
          (Ast.Complexity.calculate c));
    Alcotest.test_case "match expression" `Quick (fun () ->
        let expr = Ast.Match { expr = Ast.Ident "x"; cases = 3 } in
        let c = Ast.Complexity.analyze_expr expr in
        Alcotest.(check int) "match_cases count" 2 c.match_cases;
        Alcotest.(check int) "total" 2 c.total;
        Alcotest.(check int)
          "cyclomatic complexity" 3
          (Ast.Complexity.calculate c));
    Alcotest.test_case "try expression" `Quick (fun () ->
        let expr = Ast.Try { expr = Ast.Constant "risky"; handlers = 2 } in
        let c = Ast.Complexity.analyze_expr expr in
        Alcotest.(check int) "try_handlers count" 2 c.try_handlers;
        Alcotest.(check int) "total" 2 c.total;
        Alcotest.(check int)
          "cyclomatic complexity" 3
          (Ast.Complexity.calculate c));
    Alcotest.test_case "boolean operators" `Quick (fun () ->
        let expr =
          Ast.Apply
            {
              func = Ast.Ident "Stdlib.&&";
              args = [ Ast.Constant "true"; Ast.Constant "false" ];
            }
        in
        let c = Ast.Complexity.analyze_expr expr in
        Alcotest.(check int) "boolean_operators count" 1 c.boolean_operators;
        Alcotest.(check int) "total" 1 c.total;
        Alcotest.(check int)
          "cyclomatic complexity" 2
          (Ast.Complexity.calculate c));
  ]

(** Tests for visitor pattern *)
let visitor_tests =
  [
    Alcotest.test_case "visitor pattern basic traversal" `Quick (fun () ->
        let visited_nodes = ref [] in
        let test_visitor =
          object
            inherit Ast.visitor
            method! visit_ident name = visited_nodes := name :: !visited_nodes

            method! visit_constant value =
              visited_nodes := ("const:" ^ value) :: !visited_nodes
          end
        in

        let expr =
          Ast.Apply
            {
              func = Ast.Ident "print_endline";
              args = [ Ast.Constant "hello" ];
            }
        in
        test_visitor#visit_expr expr;

        let expected = [ "print_endline"; "const:hello" ] in
        Alcotest.(check (list string))
          "visited nodes" expected (List.rev !visited_nodes));
    Alcotest.test_case "visitor pattern nested traversal" `Quick (fun () ->
        let depth = ref 0 in
        let max_depth = ref 0 in
        let test_visitor =
          object
            inherit Ast.visitor as super

            method! visit_if_then_else ~cond ~then_expr ~else_expr =
              incr depth;
              max_depth := max !max_depth !depth;
              super#visit_if_then_else ~cond ~then_expr ~else_expr;
              decr depth
          end
        in

        let nested_if =
          Ast.If_then_else
            {
              cond = Ast.Ident "x";
              then_expr =
                Ast.If_then_else
                  {
                    cond = Ast.Ident "y";
                    then_expr = Ast.Constant "1";
                    else_expr = None;
                  };
              else_expr = Some (Ast.Constant "0");
            }
        in

        test_visitor#visit_expr nested_if;
        Alcotest.(check int) "max nesting depth" 2 !max_depth);
    Alcotest.test_case "visitor pattern sequence traversal" `Quick (fun () ->
        let node_count = ref 0 in
        let test_visitor =
          object
            inherit Ast.visitor as super

            method! visit_expr expr =
              incr node_count;
              super#visit_expr expr
          end
        in

        let seq_expr =
          Ast.Sequence
            [
              Ast.Constant "1";
              Ast.Constant "2";
              Ast.Apply { func = Ast.Ident "f"; args = [ Ast.Constant "3" ] };
            ]
        in

        test_visitor#visit_expr seq_expr;
        (* Should visit: Sequence + 3 Constants + Apply + Ident = 6 nodes *)
        Alcotest.(check int) "node count" 6 !node_count);
  ]

(** Tests for function finder visitor *)
let function_finder_tests =
  [
    Alcotest.test_case "function finder finds target function" `Quick (fun () ->
        let finder = new Ast.function_finder_visitor "target_func" in

        let let_expr =
          Ast.Let
            {
              bindings =
                [
                  ("other_func", Ast.Constant "1");
                  ("target_func", Ast.Ident "found_it");
                  ("another_func", Ast.Constant "2");
                ];
              body = Ast.Constant "body";
            }
        in

        finder#visit_expr let_expr;

        match finder#get_result with
        | Some (Ast.Ident "found_it") -> ()
        | _ -> Alcotest.fail "Should have found target_func");
    Alcotest.test_case "function finder returns None when not found" `Quick
      (fun () ->
        let finder = new Ast.function_finder_visitor "missing_func" in

        let let_expr =
          Ast.Let
            {
              bindings = [ ("other_func", Ast.Constant "1") ];
              body = Ast.Constant "body";
            }
        in

        finder#visit_expr let_expr;

        match finder#get_result with
        | None -> ()
        | Some _ -> Alcotest.fail "Should not have found missing_func");
    Alcotest.test_case "function finder works with nested let" `Quick (fun () ->
        let finder = new Ast.function_finder_visitor "inner_func" in

        let nested_let =
          Ast.Let
            {
              bindings = [ ("outer", Ast.Constant "1") ];
              body =
                Ast.Let
                  {
                    bindings = [ ("inner_func", Ast.Constant "found") ];
                    body = Ast.Constant "result";
                  };
            }
        in

        finder#visit_expr nested_let;

        match finder#get_result with
        | Some (Ast.Constant "found") -> ()
        | _ -> Alcotest.fail "Should have found inner_func");
    Alcotest.test_case "function finder with complex expression" `Quick
      (fun () ->
        let finder = new Ast.function_finder_visitor "complex_func" in

        let complex_expr =
          Ast.If_then_else
            {
              cond = Ast.Constant "true";
              then_expr =
                Ast.Let
                  {
                    bindings =
                      [
                        ( "complex_func",
                          Ast.Match { expr = Ast.Ident "x"; cases = 2 } );
                      ];
                    body = Ast.Constant "done";
                  };
              else_expr = None;
            }
        in

        finder#visit_expr complex_expr;

        match finder#get_result with
        | Some (Ast.Match { cases = 2; _ }) -> ()
        | _ ->
            Alcotest.fail "Should have found complex_func with Match expression");
  ]

(** Tests for nesting depth calculation using visitor *)
let nesting_visitor_tests =
  [
    Alcotest.test_case "nesting depth simple if" `Quick (fun () ->
        let simple_if =
          Ast.If_then_else
            {
              cond = Ast.Ident "x";
              then_expr = Ast.Constant "1";
              else_expr = None;
            }
        in
        let depth = Ast.Nesting.calculate_depth simple_if in
        Alcotest.(check int) "simple if depth" 1 depth);
    Alcotest.test_case "nesting depth nested if" `Quick (fun () ->
        let nested_if =
          Ast.If_then_else
            {
              cond = Ast.Ident "x";
              then_expr =
                Ast.If_then_else
                  {
                    cond = Ast.Ident "y";
                    then_expr =
                      Ast.If_then_else
                        {
                          cond = Ast.Ident "z";
                          then_expr = Ast.Constant "deep";
                          else_expr = None;
                        };
                    else_expr = None;
                  };
              else_expr = None;
            }
        in
        let depth = Ast.Nesting.calculate_depth nested_if in
        Alcotest.(check int) "nested if depth" 3 depth);
    Alcotest.test_case "nesting depth match expression" `Quick (fun () ->
        let match_expr =
          Ast.Match
            {
              expr =
                Ast.If_then_else
                  {
                    cond = Ast.Ident "x";
                    then_expr = Ast.Constant "1";
                    else_expr = None;
                  };
              cases = 3;
            }
        in
        let depth = Ast.Nesting.calculate_depth match_expr in
        Alcotest.(check int) "match with nested if depth" 2 depth);
    Alcotest.test_case "nesting depth function expression" `Quick (fun () ->
        let func_expr =
          Ast.Function
            {
              params = 1;
              body =
                Ast.If_then_else
                  {
                    cond = Ast.Ident "x";
                    then_expr = Ast.Constant "1";
                    else_expr = None;
                  };
            }
        in
        let depth = Ast.Nesting.calculate_depth func_expr in
        Alcotest.(check int) "function with if depth" 2 depth);
    Alcotest.test_case "nesting depth complex nested structure" `Quick
      (fun () ->
        let complex_expr =
          Ast.If_then_else
            {
              cond = Ast.Ident "a";
              then_expr = Ast.Match { expr = Ast.Ident "b"; cases = 2 };
              else_expr =
                Some
                  (Ast.Try
                     {
                       expr =
                         Ast.Function
                           {
                             params = 1;
                             body =
                               Ast.If_then_else
                                 {
                                   cond = Ast.Ident "c";
                                   then_expr = Ast.Constant "deep";
                                   else_expr = None;
                                 };
                           };
                       handlers = 1;
                     });
            }
        in
        let depth = Ast.Nesting.calculate_depth complex_expr in
        (* if(1) + try(1) + function(1) + inner if(1) = 4 levels deep *)
        Alcotest.(check int) "complex nested depth" 4 depth);
  ]

(** Tests for complexity visitor *)
let complexity_visitor_tests =
  [
    Alcotest.test_case "complexity visitor if-then-else" `Quick (fun () ->
        let if_expr =
          Ast.If_then_else
            {
              cond = Ast.Ident "x";
              then_expr = Ast.Constant "1";
              else_expr = Some (Ast.Constant "0");
            }
        in
        let info = Ast.Complexity.analyze_expr if_expr in
        Alcotest.(check int) "if-then-else count" 1 info.if_then_else;
        Alcotest.(check int) "total complexity" 1 info.total);
    Alcotest.test_case "complexity visitor match cases" `Quick (fun () ->
        let match_expr =
          Ast.Match
            {
              expr = Ast.Ident "x";
              cases = 4 (* 4 cases = 3 decision points *);
            }
        in
        let info = Ast.Complexity.analyze_expr match_expr in
        Alcotest.(check int) "match cases" 3 info.match_cases;
        Alcotest.(check int) "total complexity" 3 info.total);
    Alcotest.test_case "complexity visitor boolean operators" `Quick (fun () ->
        let bool_expr =
          Ast.Apply
            { func = Ast.Ident "&&"; args = [ Ast.Ident "x"; Ast.Ident "y" ] }
        in
        let info = Ast.Complexity.analyze_expr bool_expr in
        Alcotest.(check int) "boolean operators" 1 info.boolean_operators;
        Alcotest.(check int) "total complexity" 1 info.total);
    Alcotest.test_case "complexity visitor try handlers" `Quick (fun () ->
        let try_expr = Ast.Try { expr = Ast.Constant "risky"; handlers = 3 } in
        let info = Ast.Complexity.analyze_expr try_expr in
        Alcotest.(check int) "try handlers" 3 info.try_handlers;
        Alcotest.(check int) "total complexity" 3 info.total);
    Alcotest.test_case "complexity visitor complex expression" `Quick (fun () ->
        let complex_expr =
          Ast.If_then_else
            {
              cond =
                Ast.Apply
                  {
                    func = Ast.Ident "||";
                    args = [ Ast.Ident "a"; Ast.Ident "b" ];
                  };
              then_expr =
                Ast.Match
                  { expr = Ast.Ident "x"; cases = 3 (* 2 decision points *) };
              else_expr =
                Some (Ast.Try { expr = Ast.Constant "1"; handlers = 2 });
            }
        in
        let info = Ast.Complexity.analyze_expr complex_expr in
        (* 1 if + 1 boolean + 2 match + 2 try = 6 total *)
        Alcotest.(check int) "total complexity" 6 info.total;
        Alcotest.(check int) "if-then-else count" 1 info.if_then_else;
        Alcotest.(check int) "boolean operators" 1 info.boolean_operators;
        Alcotest.(check int) "match cases" 2 info.match_cases;
        Alcotest.(check int) "try handlers" 2 info.try_handlers);
    Alcotest.test_case "complexity visitor nested expressions" `Quick (fun () ->
        let nested_expr =
          Ast.If_then_else
            {
              cond = Ast.Ident "x";
              then_expr =
                Ast.If_then_else
                  {
                    cond =
                      Ast.Apply
                        {
                          func = Ast.Ident "&&";
                          args = [ Ast.Ident "y"; Ast.Ident "z" ];
                        };
                    then_expr = Ast.Constant "1";
                    else_expr = None;
                  };
              else_expr = None;
            }
        in
        let info = Ast.Complexity.analyze_expr nested_expr in
        (* 2 if + 1 boolean = 3 total *)
        Alcotest.(check int) "total complexity" 3 info.total;
        Alcotest.(check int) "if-then-else count" 2 info.if_then_else;
        Alcotest.(check int) "boolean operators" 1 info.boolean_operators);
  ]

let suite =
  [
    ( "ast",
      complexity_tests @ visitor_tests @ function_finder_tests
      @ nesting_visitor_tests @ complexity_visitor_tests );
  ]
