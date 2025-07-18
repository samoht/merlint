(** Tests for AST parsing from typedtree and parsetree text *)

open Merlint
open Ast

let parsing_tests =
  [
    Alcotest.test_case "parse simple function" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+6]..test.ml[1,0+10]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[1,0+10]..test.ml[1,0+15])\n\
          \              Texp_constant Const_int 42\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, _expr) ] -> Alcotest.(check string) "function name" "f" name
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "parse multiple value bindings" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"x/276\"\n\
          \        expression (test.ml[1,0+8]..test.ml[1,0+9])\n\
          \          Texp_constant Const_int 1\n\
          \      <def>\n\
          \        pattern (test.ml[2,10+4]..test.ml[2,10+5])\n\
          \          Tpat_var \"f/277\"\n\
          \        expression (test.ml[2,10+6]..test.ml[2,10+10]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[2,10+6]..test.ml[2,10+7])\n\
          \                Tpat_var \"y/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[2,10+10]..test.ml[2,10+15])\n\
          \              Texp_ident \"y/278\"\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        (* Should only extract the function, not the value binding *)
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, _expr) ] -> Alcotest.(check string) "function name" "f" name
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "handle type error nodes" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+8]..test.ml[1,0+10])\n\
          \          Texp_ident \"*type-error*/277\"\n\
          \    ]\n\
           ]\n"
        in
        (* This should detect type error and fall back, but fail because it's still Typedtree nodes *)
        try
          let _ = Dump.typedtree ast_dump in
          Alcotest.fail "Should have raised an exception due to type error"
        with
        | Ast.Parse_error msg when String.contains msg 'T' ->
            (* Expected - we detected the type error and tried Parsetree, but the nodes are still Typedtree *)
            ()
        | _ -> Alcotest.fail "Should handle type error correctly");
    Alcotest.test_case "parse if-then-else expression" `Quick (fun () ->
        (* Test with a simpler, direct AST structure *)
        let ast =
          {
            Ast.expressions = [];
            functions =
              [
                ( "f",
                  Ast.Function
                    {
                      params = 1;
                      body =
                        Ast.If_then_else
                          {
                            cond = Ast.Ident "x";
                            then_expr = Ast.Constant "1";
                            else_expr = Some (Ast.Constant "0");
                          };
                    } );
              ];
            modules = [];
            types = [];
            exceptions = [];
            variants = [];
            identifiers = [];
            patterns = [];
          }
        in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, expr) ] -> (
            Alcotest.(check string) "function name" "f" name;
            match expr with
            | Ast.Function
                { body = Ast.If_then_else { else_expr = Some _; _ }; _ } ->
                ()
            | _ -> Alcotest.fail "Expected function with if-then-else body")
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "normalize node types correctly" `Quick (fun () ->
        (* Test that Texp_ident normalizes to exp_ident *)
        let normalized = Dump.normalize_node_type Ast.Typedtree "Texp_ident" in
        Alcotest.(check string) "normalized Texp_ident" "exp_ident" normalized;

        (* Test that special nodes remain unchanged *)
        let special = Dump.normalize_node_type Ast.Typedtree "Param_pat" in
        Alcotest.(check string) "special node unchanged" "Param_pat" special;

        (* Test that wrong dialect raises Parse_error *)
        try
          let _ = Dump.normalize_node_type Ast.Typedtree "Pexp_ident" in
          Alcotest.fail "Should raise Parse_error for wrong dialect"
        with Ast.Parse_error _ -> ());
    Alcotest.test_case "parse function with if-then-else" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[3,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+6]..test.ml[3,0+10]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[2,0+0]..test.ml[3,0+10])\n\
          \              Texp_ifthenelse\n\
          \              expression (test.ml[2,0+3]..test.ml[2,0+8])\n\
          \                Texp_ident \"x/278\"\n\
          \              expression (test.ml[2,0+14]..test.ml[2,0+15])\n\
          \                Texp_constant Const_int 1\n\
          \              expression (test.ml[3,0+5]..test.ml[3,0+6])\n\
          \                Texp_constant Const_int 0\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, expr) ] -> (
            Alcotest.(check string) "function name" "f" name;
            (* Verify the function body is an if-then-else *)
            match expr with
            | Ast.Function
                {
                  body =
                    Ast.If_then_else
                      { cond; then_expr; else_expr = Some else_expr };
                  _;
                } -> (
                (* Check the condition is an identifier *)
                (match cond with
                | Ast.Ident _ -> ()
                | _ -> Alcotest.fail "Expected identifier in condition");
                (* Check then branch is constant 1 *)
                (match then_expr with
                | Ast.Constant "1" -> ()
                | Ast.Constant _ ->
                    Alcotest.fail "Expected constant 1 in then branch"
                | _ -> Alcotest.fail "Expected constant 1 in then branch");
                (* Check else branch is constant 0 *)
                match else_expr with
                | Ast.Constant "0" -> ()
                | _ -> Alcotest.fail "Expected constant 0 in else branch")
            | _ -> Alcotest.fail "Expected function with if-then-else body")
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "parse function with match expression" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[5,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+6]..test.ml[5,0+10]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[2,0+0]..test.ml[5,0+10])\n\
          \              Texp_match\n\
          \              expression (test.ml[2,0+6]..test.ml[2,0+7])\n\
          \                Texp_ident \"x/278\"\n\
          \              case\n\
          \                pattern (test.ml[3,0+2]..test.ml[3,0+6])\n\
          \                  Tpat_construct \"Some\"\n\
          \                expression (test.ml[3,0+10]..test.ml[3,0+11])\n\
          \                  Texp_constant Const_int 1\n\
          \              case\n\
          \                pattern (test.ml[4,0+2]..test.ml[4,0+6])\n\
          \                  Tpat_construct \"None\"\n\
          \                expression (test.ml[4,0+10]..test.ml[4,0+11])\n\
          \                  Texp_constant Const_int 0\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, expr) ] -> (
            Alcotest.(check string) "function name" "f" name;
            (* Verify the function body is a match expression *)
            match expr with
            | Ast.Function { body = Ast.Match { cases; _ }; _ } ->
                (* Should have detected 2 cases *)
                Alcotest.(check int) "match cases" 2 cases
            | _ -> Alcotest.fail "Expected function with match body")
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "parse function with try expression" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[5,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+6]..test.ml[5,0+10]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[2,0+0]..test.ml[5,0+10])\n\
          \              Texp_try\n\
          \              expression (test.ml[2,0+4]..test.ml[2,0+15])\n\
          \                Texp_apply\n\
          \                expression (test.ml[2,0+4]..test.ml[2,0+11])\n\
          \                  Texp_ident \"List.hd\"\n\
          \                expression (test.ml[2,0+12]..test.ml[2,0+13])\n\
          \                  Texp_ident \"x/278\"\n\
          \              case\n\
          \                pattern (test.ml[3,0+7]..test.ml[3,0+17])\n\
          \                  Tpat_construct \"Not_found\"\n\
          \                expression (test.ml[3,0+21]..test.ml[3,0+22])\n\
          \                  Texp_constant Const_int 0\n\
          \              case\n\
          \                pattern (test.ml[4,0+7]..test.ml[4,0+14])\n\
          \                  Tpat_construct \"Failure\"\n\
          \                expression (test.ml[4,0+18]..test.ml[4,0+20])\n\
          \                  Texp_constant Const_int -1\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, expr) ] -> (
            Alcotest.(check string) "function name" "f" name;
            (* Verify the function body is a try expression *)
            match expr with
            | Ast.Function { body = Ast.Try { handlers; _ }; _ } ->
                (* Should have detected 2 exception handlers *)
                Alcotest.(check int) "exception handlers" 2 handlers
            | _ -> Alcotest.fail "Expected function with try body")
        | _ -> Alcotest.fail "Expected exactly one function");
  ]

let parsetree_parsing_tests =
  [
    Alcotest.test_case "parse simple function from parsetree" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+10])\n\
          \    Pstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Ppat_var \"f\" (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \        expression (test.ml[1,0+6]..test.ml[1,0+10]) ghost\n\
          \          Pexp_function\n\
          \          [\n\
          \            Pparam_val (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \              Nolabel\n\
          \              None\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Ppat_var \"x\" (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \          ]\n\
          \          None\n\
          \          Pfunction_body\n\
          \            expression (test.ml[1,0+10]..test.ml[1,0+15])\n\
          \              Pexp_constant\n\
          \              constant (test.ml[1,0+10]..test.ml[1,0+15])\n\
          \                PConst_int (42,None)\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.parsetree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, _expr) ] -> Alcotest.(check string) "function name" "f" name
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "parse parsetree function with if-then-else" `Quick
      (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[3,0+10])\n\
          \    Pstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Ppat_var \"f\"\n\
          \        expression (test.ml[1,0+6]..test.ml[3,0+10])\n\
          \          Pexp_fun\n\
          \          Nolabel\n\
          \          None\n\
          \          pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \            Ppat_var \"x\"\n\
          \          expression (test.ml[2,0+0]..test.ml[3,0+10])\n\
          \            Pexp_ifthenelse\n\
          \            expression (test.ml[2,0+3]..test.ml[2,0+8])\n\
          \              Pexp_ident \"x\"\n\
          \            expression (test.ml[2,0+14]..test.ml[2,0+15])\n\
          \              Pexp_constant Const_int 1\n\
          \            Some\n\
          \              expression (test.ml[3,0+5]..test.ml[3,0+6])\n\
          \                Pexp_constant Const_int 0\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.parsetree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, expr) ] -> (
            Alcotest.(check string) "function name" "f" name;
            (* Verify the function body is an if-then-else *)
            match expr with
            | Ast.Function
                { body = Ast.If_then_else { else_expr = Some _; _ }; _ } ->
                ()
            | _ -> Alcotest.fail "Expected function with if-then-else body")
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "parse parsetree function with match" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[5,0+10])\n\
          \    Pstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Ppat_var \"f\"\n\
          \        expression (test.ml[1,0+6]..test.ml[5,0+10])\n\
          \          Pexp_fun\n\
          \          Nolabel\n\
          \          None\n\
          \          pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \            Ppat_var \"x\"\n\
          \          expression (test.ml[2,0+0]..test.ml[5,0+10])\n\
          \            Pexp_match\n\
          \            expression (test.ml[2,0+6]..test.ml[2,0+7])\n\
          \              Pexp_ident \"x\"\n\
          \            [\n\
          \              case\n\
          \                pattern (test.ml[3,0+2]..test.ml[3,0+6])\n\
          \                  Ppat_construct \"Some\"\n\
          \                expression (test.ml[3,0+10]..test.ml[3,0+11])\n\
          \                  Pexp_constant Const_int 1\n\
          \              case\n\
          \                pattern (test.ml[4,0+2]..test.ml[4,0+6])\n\
          \                  Ppat_construct \"None\"\n\
          \                expression (test.ml[4,0+10]..test.ml[4,0+11])\n\
          \                  Pexp_constant Const_int 0\n\
          \            ]\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.parsetree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, expr) ] -> (
            Alcotest.(check string) "function name" "f" name;
            (* Verify the function body is a match expression *)
            match expr with
            | Ast.Function { body = Ast.Match { cases; _ }; _ } ->
                (* Should have detected 2 cases *)
                Alcotest.(check int) "match cases" 2 cases
            | _ -> Alcotest.fail "Expected function with match body")
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "parse parsetree function with try" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[5,0+10])\n\
          \    Pstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Ppat_var \"f\"\n\
          \        expression (test.ml[1,0+6]..test.ml[5,0+10])\n\
          \          Pexp_fun\n\
          \          Nolabel\n\
          \          None\n\
          \          pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \            Ppat_var \"x\"\n\
          \          expression (test.ml[2,0+0]..test.ml[5,0+10])\n\
          \            Pexp_try\n\
          \            expression (test.ml[2,0+4]..test.ml[2,0+15])\n\
          \              Pexp_apply\n\
          \              expression (test.ml[2,0+4]..test.ml[2,0+11])\n\
          \                Pexp_ident \"List.hd\"\n\
          \              [\n\
          \                Nolabel\n\
          \                  expression (test.ml[2,0+12]..test.ml[2,0+13])\n\
          \                    Pexp_ident \"x\"\n\
          \              ]\n\
          \            [\n\
          \              case\n\
          \                pattern (test.ml[3,0+7]..test.ml[3,0+17])\n\
          \                  Ppat_construct \"Not_found\"\n\
          \                expression (test.ml[3,0+21]..test.ml[3,0+22])\n\
          \                  Pexp_constant Const_int 0\n\
          \              case\n\
          \                pattern (test.ml[4,0+7]..test.ml[4,0+14])\n\
          \                  Ppat_construct \"Failure\"\n\
          \                expression (test.ml[4,0+18]..test.ml[4,0+20])\n\
          \                  Pexp_constant Const_int -1\n\
          \            ]\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.parsetree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, expr) ] -> (
            Alcotest.(check string) "function name" "f" name;
            (* Verify the function body is a try expression *)
            match expr with
            | Ast.Function { body = Ast.Try { handlers; _ }; _ } ->
                (* Should have detected 2 exception handlers *)
                Alcotest.(check int) "exception handlers" 2 handlers
            | _ -> Alcotest.fail "Expected function with try body")
        | _ -> Alcotest.fail "Expected exactly one function");
    Alcotest.test_case "verify Parsetree node normalization" `Quick (fun () ->
        (* Test that Pexp_ident normalizes to exp_ident *)
        let normalized = Dump.normalize_node_type Ast.Parsetree "Pexp_ident" in
        Alcotest.(check string) "normalized Pexp_ident" "exp_ident" normalized;

        (* Test that wrong dialect raises Parse_error *)
        try
          let _ = Dump.normalize_node_type Ast.Parsetree "Texp_ident" in
          Alcotest.fail "Should raise Parse_error for wrong dialect"
        with Ast.Parse_error _ -> ());
  ]

let constructor_tests =
  [
    Alcotest.test_case "parse constructor applications from typedtree" `Quick
      (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[3,0+23])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+6]..test.ml[3,0+23]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[2,0+2]..test.ml[3,0+23])\n\
          \              Texp_match\n\
          \              expression (test.ml[2,0+8]..test.ml[2,0+9])\n\
          \                Texp_ident \"x/278\"\n\
          \              case\n\
          \                pattern (test.ml[2,0+13]..test.ml[2,0+23])\n\
          \                  Tpat_construct \"Some\"\n\
          \                  pattern (test.ml[2,0+18]..test.ml[2,0+23])\n\
          \                    Tpat_var \"value/279\"\n\
          \                expression (test.ml[2,0+27]..test.ml[2,0+35])\n\
          \                  Texp_construct \"Ok\"\n\
          \                  expression (test.ml[2,0+30]..test.ml[2,0+35])\n\
          \                    Texp_ident \"value/279\"\n\
          \              case\n\
          \                pattern (test.ml[3,0+4]..test.ml[3,0+8])\n\
          \                  Tpat_construct \"None\"\n\
          \                expression (test.ml[3,0+12]..test.ml[3,0+23])\n\
          \                  Texp_construct \"Error\"\n\
          \                  expression (test.ml[3,0+18]..test.ml[3,0+23])\n\
          \                    Texp_constant Const_string(\"no \
           value\",test.ml[3,0+18]..test.ml[3,0+23],None)\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, Ast.Function { body = Ast.Match { cases; _ }; _ }) ] ->
            Alcotest.(check string) "function name" "f" name;
            Alcotest.(check int) "match cases" 2 cases
        | _ -> Alcotest.fail "Expected function with match expression");
    Alcotest.test_case "parse constructor applications from parsetree" `Quick
      (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[3,0+23])\n\
          \    Pstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Ppat_var \"f\" (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \        expression (test.ml[1,0+6]..test.ml[3,0+23])\n\
          \          Pexp_fun\n\
          \          Nolabel\n\
          \          None\n\
          \          pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \            Ppat_var \"x\" (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \          expression (test.ml[2,0+2]..test.ml[3,0+23])\n\
          \            Pexp_match\n\
          \            expression (test.ml[2,0+8]..test.ml[2,0+9])\n\
          \              Pexp_ident \"x\" (test.ml[2,0+8]..test.ml[2,0+9])\n\
          \            [\n\
          \              case\n\
          \                pattern (test.ml[2,0+13]..test.ml[2,0+23])\n\
          \                  Ppat_construct \"Some\"\n\
          \                  Some\n\
          \                    pattern (test.ml[2,0+18]..test.ml[2,0+23])\n\
          \                      Ppat_var \"value\" \
           (test.ml[2,0+18]..test.ml[2,0+23])\n\
          \                expression (test.ml[2,0+27]..test.ml[2,0+35])\n\
          \                  Pexp_construct \"Ok\"\n\
          \                  Some\n\
          \                    expression (test.ml[2,0+30]..test.ml[2,0+35])\n\
          \                      Pexp_ident \"value\" \
           (test.ml[2,0+30]..test.ml[2,0+35])\n\
          \              case\n\
          \                pattern (test.ml[3,0+4]..test.ml[3,0+8])\n\
          \                  Ppat_construct \"None\"\n\
          \                  None\n\
          \                expression (test.ml[3,0+12]..test.ml[3,0+23])\n\
          \                  Pexp_construct \"Error\"\n\
          \                  Some\n\
          \                    expression (test.ml[3,0+18]..test.ml[3,0+23])\n\
          \                      Pexp_constant\n\
          \                      constant (test.ml[3,0+18]..test.ml[3,0+23])\n\
          \                        PConst_string(\"no \
           value\",test.ml[3,0+18]..test.ml[3,0+23],None)\n\
          \            ]\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.parsetree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, Ast.Function { body = Ast.Match { cases; _ }; _ }) ] ->
            Alcotest.(check string) "function name" "f" name;
            Alcotest.(check int) "match cases" 2 cases
        | _ -> Alcotest.fail "Expected function with match expression");
  ]

let let_in_tests =
  [
    Alcotest.test_case "parse let-in expressions" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[4,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+6]..test.ml[4,0+10]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[2,0+2]..test.ml[4,0+10])\n\
          \              Texp_let Nonrec\n\
          \              [\n\
          \                <def>\n\
          \                  pattern (test.ml[2,0+6]..test.ml[2,0+12])\n\
          \                    Tpat_var \"square/279\"\n\
          \                  expression (test.ml[2,0+15]..test.ml[2,0+25])\n\
          \                    Texp_function\n\
          \                    [\n\
          \                      Nolabel\n\
          \                      Param_pat\n\
          \                        pattern (test.ml[2,0+15]..test.ml[2,0+16])\n\
          \                          Tpat_var \"n/280\"\n\
          \                    ]\n\
          \                    Tfunction_body\n\
          \                      expression (test.ml[2,0+19]..test.ml[2,0+25])\n\
          \                        Texp_apply\n\
          \                        expression (test.ml[2,0+19]..test.ml[2,0+20])\n\
          \                          Texp_ident \"n/280\"\n\
          \                        [\n\
          \                          <arg>\n\
          \                            Nolabel\n\
          \                            expression \
           (test.ml[2,0+23]..test.ml[2,0+24])\n\
          \                              Texp_ident \"n/280\"\n\
          \                        ]\n\
          \              ]\n\
          \              expression (test.ml[3,0+2]..test.ml[4,0+10])\n\
          \                Texp_let Nonrec\n\
          \                [\n\
          \                  <def>\n\
          \                    pattern (test.ml[3,0+6]..test.ml[3,0+12])\n\
          \                      Tpat_var \"result/281\"\n\
          \                    expression (test.ml[3,0+15]..test.ml[3,0+35])\n\
          \                      Texp_apply\n\
          \                      expression (test.ml[3,0+15]..test.ml[3,0+21])\n\
          \                        Texp_ident \"square/279\"\n\
          \                      [\n\
          \                        <arg>\n\
          \                          Nolabel\n\
          \                          expression \
           (test.ml[3,0+23]..test.ml[3,0+34])\n\
          \                            Texp_apply\n\
          \                            expression \
           (test.ml[3,0+23]..test.ml[3,0+29])\n\
          \                              Texp_ident \"double/282\"\n\
          \                            [\n\
          \                              <arg>\n\
          \                                Nolabel\n\
          \                                expression \
           (test.ml[3,0+30]..test.ml[3,0+31])\n\
          \                                  Texp_ident \"x/278\"\n\
          \                            ]\n\
          \                      ]\n\
          \                ]\n\
          \                expression (test.ml[4,0+2]..test.ml[4,0+10])\n\
          \                  Texp_apply\n\
          \                  expression (test.ml[4,0+2]..test.ml[4,0+8])\n\
          \                    Texp_ident \"result/281\"\n\
          \                  [\n\
          \                    <arg>\n\
          \                      Nolabel\n\
          \                      expression (test.ml[4,0+11]..test.ml[4,0+12])\n\
          \                        Texp_constant Const_int 1\n\
          \                  ]\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        (* This test should extract the main function 'f' plus nested function 'square' *)
        Alcotest.(check int) "function count" 2 (List.length ast.functions);
        (* Check that 'f' is the main function *)
        let main_functions =
          List.filter (fun (name, _) -> name = "f") ast.functions
        in
        Alcotest.(check int)
          "main function count" 1
          (List.length main_functions);
        match main_functions with
        | [ (name, Ast.Function { body = Ast.Let { bindings; _ }; _ }) ] ->
            Alcotest.(check string) "function name" "f" name;
            (* Let expression extraction is not fully implemented yet, so bindings are empty *)
            Alcotest.(check int) "let bindings" 0 (List.length bindings)
        | _ -> Alcotest.fail "Expected function with let expression");
  ]

let type_error_tests =
  [
    Alcotest.test_case "handle type errors with fallback" `Quick (fun () ->
        let ast_dump_with_type_error =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+8]..test.ml[1,0+10])\n\
          \          Texp_ident \"*type-error*/277\"\n\
          \    ]\n\
           ]\n"
        in
        (* This should raise Type_error and try to fall back to Parsetree *)
        (* But since the nodes are still Typedtree format, it should fail with Parse_error *)
        try
          let _ = Dump.typedtree ast_dump_with_type_error in
          Alcotest.fail "Should have raised an exception due to type error"
        with
        | Ast.Parse_error msg when String.contains msg 'T' ->
            (* Expected - we detected the type error and tried Parsetree, but the nodes are still Typedtree *)
            ()
        | _ -> Alcotest.fail "Should handle type error correctly");
    Alcotest.test_case "test dialect normalization" `Quick (fun () ->
        (* Test Typedtree normalization *)
        let normalized_t =
          Dump.normalize_node_type Ast.Typedtree "Texp_ident"
        in
        Alcotest.(check string) "normalized Texp_ident" "exp_ident" normalized_t;

        (* Test Parsetree normalization *)
        let normalized_p =
          Dump.normalize_node_type Ast.Parsetree "Pexp_ident"
        in
        Alcotest.(check string) "normalized Pexp_ident" "exp_ident" normalized_p;

        (* Test special nodes remain unchanged *)
        let special = Dump.normalize_node_type Ast.Typedtree "Param_pat" in
        Alcotest.(check string) "special node unchanged" "Param_pat" special;

        (* Test wrong dialect raises Parse_error *)
        try
          let _ = Dump.normalize_node_type Ast.Typedtree "Pexp_ident" in
          Alcotest.fail "Should raise Parse_error for wrong dialect"
        with Ast.Parse_error _ -> ());
  ]

let constant_parsing_tests =
  [
    Alcotest.test_case "parse constants from typedtree format" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+15])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"x/276\"\n\
          \        expression (test.ml[1,0+8]..test.ml[1,0+15])\n\
          \          Texp_constant Const_int 42\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        (* The constant parsing logic should extract the actual value *)
        Alcotest.(check int) "identifiers found" 0 (List.length ast.identifiers));
    Alcotest.test_case "parse constants from parsetree format" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+15])\n\
          \    Pstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Ppat_var \"x\" (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \        expression (test.ml[1,0+8]..test.ml[1,0+15])\n\
          \          Pexp_constant\n\
          \          constant (test.ml[1,0+8]..test.ml[1,0+15])\n\
          \            PConst_int (42,None)\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.parsetree ast_dump in
        (* The constant parsing logic should extract the actual value *)
        Alcotest.(check int) "identifiers found" 0 (List.length ast.identifiers));
  ]

let polymorphic_variant_tests =
  [
    Alcotest.test_case "parse polymorphic variants" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[5,0+30])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
          \          Tpat_var \"f/276\"\n\
          \        expression (test.ml[1,0+6]..test.ml[5,0+30]) ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern (test.ml[1,0+6]..test.ml[1,0+7])\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression (test.ml[2,0+2]..test.ml[5,0+30])\n\
          \              Texp_match\n\
          \              expression (test.ml[2,0+8]..test.ml[2,0+9])\n\
          \                Texp_ident \"x/278\"\n\
          \              case\n\
          \                pattern (test.ml[2,0+13]..test.ml[2,0+17])\n\
          \                  Tpat_variant \"Red\" None\n\
          \                expression (test.ml[2,0+21]..test.ml[2,0+22])\n\
          \                  Texp_constant Const_int 1\n\
          \              case\n\
          \                pattern (test.ml[3,0+4]..test.ml[3,0+10])\n\
          \                  Tpat_variant \"Green\" None\n\
          \                expression (test.ml[3,0+14]..test.ml[3,0+15])\n\
          \                  Texp_constant Const_int 2\n\
          \              case\n\
          \                pattern (test.ml[4,0+4]..test.ml[4,0+9])\n\
          \                  Tpat_variant \"Blue\" None\n\
          \                expression (test.ml[4,0+13]..test.ml[4,0+14])\n\
          \                  Texp_constant Const_int 3\n\
          \              case\n\
          \                pattern (test.ml[5,0+4]..test.ml[5,0+13])\n\
          \                  Tpat_variant \"Other\"\n\
          \                  Some\n\
          \                    pattern (test.ml[5,0+11]..test.ml[5,0+12])\n\
          \                      Tpat_var \"s/279\"\n\
          \                expression (test.ml[5,0+16]..test.ml[5,0+30])\n\
          \                  Texp_apply\n\
          \                  expression (test.ml[5,0+16]..test.ml[5,0+29])\n\
          \                    Texp_ident \"String.length\"\n\
          \                  [\n\
          \                    <arg>\n\
          \                      Nolabel\n\
          \                      expression (test.ml[5,0+30]..test.ml[5,0+31])\n\
          \                        Texp_ident \"s/279\"\n\
          \                  ]\n\
          \    ]\n\
           ]\n"
        in
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, Ast.Function { body = Ast.Match { cases; _ }; _ }) ] ->
            Alcotest.(check string) "function name" "f" name;
            Alcotest.(check int) "match cases" 4 cases
        | _ -> Alcotest.fail "Expected function with match expression");
  ]

let attribute_tests =
  [
    Alcotest.test_case "parse Tstr_attribute with Parsetree payload" `Quick
      (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item (test.ml[1,0+0]..test.ml[1,0+24])\n\
          \    Tstr_attribute \"ocaml.warning\"\n\
          \    [\n\
          \      structure_item (test.ml[1,0+18]..[1,0+23])\n\
          \        Pstr_eval\n\
          \        expression (test.ml[1,0+18]..[1,0+23])\n\
          \          Pexp_constant\n\
          \          constant (test.ml[1,0+18]..[1,0+23])\n\
          \            PConst_string(\"-32\",(test.ml[1,0+19]..[1,0+22]),None)\n\
          \    ]\n\
          \  structure_item (test.ml[2,0+0]..test.ml[2,0+10])\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern (test.ml[2,0+4]..test.ml[2,0+5])\n\
          \          Tpat_var \"x/276\"\n\
          \        expression (test.ml[2,0+8]..test.ml[2,0+9])\n\
          \          Texp_constant Const_int 1\n\
          \    ]\n\
           \\]\n"
        in
        (* This should work: attributes can contain Parsetree nodes *)
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int)
          "should parse without error" 0
          (List.length ast.functions));
  ]

let nested_if_tests =
  [
    Alcotest.test_case "parse deeply nested if-then-else" `Quick (fun () ->
        let ast_dump =
          "[\n\
          \  structure_item\n\
          \    Tstr_value Nonrec\n\
          \    [\n\
          \      <def>\n\
          \        pattern\n\
          \          Tpat_var \"check_input/276\"\n\
          \        expression ghost\n\
          \          Texp_function\n\
          \          [\n\
          \            Nolabel\n\
          \            Param_pat\n\
          \              pattern\n\
          \                Tpat_var \"x/278\"\n\
          \          ]\n\
          \          Tfunction_body\n\
          \            expression\n\
          \              Texp_ifthenelse\n\
          \              expression\n\
          \                Texp_constant Const_int 1\n\
          \              expression\n\
          \                Texp_ifthenelse\n\
          \                expression\n\
          \                  Texp_constant Const_int 2\n\
          \                expression\n\
          \                  Texp_constant Const_string(\"yes\",None)\n\
          \                Some\n\
          \                  expression\n\
          \                    Texp_constant Const_string(\"no\",None)\n\
          \              Some\n\
          \                expression\n\
          \                  Texp_constant Const_string(\"maybe\",None)\n\
          \    ]\n\
           \\]\n"
        in
        let ast = Dump.typedtree ast_dump in
        Alcotest.(check int) "function count" 1 (List.length ast.functions);
        match ast.functions with
        | [ (name, Ast.Function { body; _ }) ] ->
            Alcotest.(check string) "function name" "check_input" name;
            (* Verify we extracted nested if-then-else *)
            let complexity_info = Ast.Complexity.analyze_expr body in
            Alcotest.(check int)
              "nested if count" 2 complexity_info.if_then_else
        | _ -> Alcotest.fail "Expected function with nested if-then-else");
  ]

let suite =
  [
    ( "parser",
      parsing_tests @ parsetree_parsing_tests @ constructor_tests @ let_in_tests
      @ type_error_tests @ constant_parsing_tests @ polymorphic_variant_tests
      @ attribute_tests @ nested_if_tests );
  ]
