(** Core AST types for control flow analysis *)

let src = Logs.Src.create "merlint.ast" ~doc:"AST control flow analysis"

module Log = (val Logs.src_log src : Logs.LOG)

type expr =
  | If_then_else of { cond : expr; then_expr : expr; else_expr : expr option }
  | Match of { expr : expr; cases : int }
  | Try of { expr : expr; handlers : int }
  | Function of { params : int; body : expr }
  | Let of { bindings : (string * expr) list; body : expr }
  | Sequence of expr list
  | Other  (** Catch-all for expressions we don't need to analyze *)

type t = {
  functions : (string * expr) list;
      (** Top-level functions with their control flow *)
}

(** Cyclomatic complexity analysis *)
module Complexity = struct
  type info = {
    total : int;  (** Total number of decision points *)
    if_then_else : int;  (** Number of if-then-else expressions *)
    match_cases : int;  (** Number of match cases (beyond the first) *)
    try_handlers : int;  (** Number of exception handlers *)
    boolean_operators : int;  (** Number of && and || operators *)
  }

  let empty =
    {
      total = 0;
      if_then_else = 0;
      match_cases = 0;
      try_handlers = 0;
      boolean_operators = 0;
    }

  (** Count decision points in an AST expression node *)
  let rec analyze node =
    match node with
    | If_then_else { cond; then_expr; else_expr } -> (
        let acc = { empty with if_then_else = 1; total = 1 } in
        let acc = merge acc (analyze cond) in
        let acc = merge acc (analyze then_expr) in
        match else_expr with Some e -> merge acc (analyze e) | None -> acc)
    | Match { expr; cases } ->
        (* A match expression is a single decision point, regardless of cases *)
        let decision_points = if cases > 0 then 1 else 0 in
        let acc =
          { empty with match_cases = decision_points; total = decision_points }
        in
        merge acc (analyze expr)
    | Try { expr; handlers } ->
        (* Each exception handler adds complexity *)
        let acc = { empty with try_handlers = handlers; total = handlers } in
        merge acc (analyze expr)
    | Function { body; _ } -> analyze body
    | Let { bindings; body } ->
        let acc =
          List.fold_left
            (fun acc (_, e) -> merge acc (analyze e))
            empty bindings
        in
        merge acc (analyze body)
    | Sequence exprs ->
        List.fold_left (fun acc e -> merge acc (analyze e)) empty exprs
    | Other -> empty

  and merge acc info =
    {
      total = acc.total + info.total;
      if_then_else = acc.if_then_else + info.if_then_else;
      match_cases = acc.match_cases + info.match_cases;
      try_handlers = acc.try_handlers + info.try_handlers;
      boolean_operators = acc.boolean_operators + info.boolean_operators;
    }

  (** Calculate cyclomatic complexity from complexity info (1 + total decision
      points) *)
  let calculate info = 1 + info.total
end

(** Nesting depth analysis *)
module Nesting = struct
  (** Calculate maximum nesting depth of an AST expression node *)
  let depth node =
    let rec depth_of current_depth = function
      | If_then_else { cond; then_expr; else_expr } ->
          let new_depth = current_depth + 1 in
          let d1 = depth_of current_depth cond in
          let d2 = depth_of new_depth then_expr in
          let d3 =
            match else_expr with
            | Some e ->
                depth_of current_depth e (* else branch at same level as if *)
            | None -> new_depth
          in
          max (max d1 d2) d3
      | Match { expr; _ } | Try { expr; _ } ->
          let new_depth = current_depth + 1 in
          max (depth_of current_depth expr) new_depth
      | Function { body; _ } -> depth_of (current_depth + 1) body
      | Let { bindings; body } ->
          let bind_depth =
            List.fold_left
              (fun acc (_, e) -> max acc (depth_of current_depth e))
              current_depth bindings
          in
          max bind_depth (depth_of current_depth body)
      | Sequence exprs ->
          List.fold_left
            (fun acc e -> max acc (depth_of current_depth e))
            current_depth exprs
      | Other -> current_depth
    in
    depth_of 0 node
end

(** Convert ppxlib expression to our AST representation *)
let rec ppxlib_expr_to_ast (expr : Ppxlib.expression) : expr =
  Log.debug (fun m ->
      m "ppxlib_expr_to_ast: %s" (Ppxlib.Pprintast.string_of_expression expr));
  Log.debug (fun m ->
      m "Expression type: %s"
        (match expr.Ppxlib.pexp_desc with
        | Ppxlib.Pexp_ifthenelse _ -> "Pexp_ifthenelse"
        | Ppxlib.Pexp_match _ -> "Pexp_match"
        | Ppxlib.Pexp_try _ -> "Pexp_try"
        | Ppxlib.Pexp_function _ -> "Pexp_function"
        | Ppxlib.Pexp_let _ -> "Pexp_let"
        | Ppxlib.Pexp_sequence _ -> "Pexp_sequence"
        | _ -> "Other"));
  match expr.Ppxlib.pexp_desc with
  | Ppxlib.Pexp_ifthenelse (cond, then_expr, else_expr) ->
      If_then_else
        {
          cond = ppxlib_expr_to_ast cond;
          then_expr = ppxlib_expr_to_ast then_expr;
          else_expr = Option.map ppxlib_expr_to_ast else_expr;
        }
  | Ppxlib.Pexp_match (expr, cases) ->
      Match { expr = ppxlib_expr_to_ast expr; cases = List.length cases }
  | Ppxlib.Pexp_try (expr, cases) ->
      Try { expr = ppxlib_expr_to_ast expr; handlers = List.length cases }
  | Ppxlib.Pexp_function (params, _, body) ->
      (* In OCaml 5, multi-parameter functions have all params here *)
      Log.debug (fun m -> m "Pexp_function: %d params" (List.length params));

      let body_expr =
        match body with
        | Ppxlib.Pfunction_body expr ->
            Log.debug (fun m -> m "Found Pfunction_body");
            ppxlib_expr_to_ast expr
        | Ppxlib.Pfunction_cases (cases, _, _) ->
            Log.debug (fun m ->
                m "Found Pfunction_cases with %d cases" (List.length cases));
            (* This is a pattern matching function - treat it as a match expression *)
            Match { expr = Other; cases = List.length cases }
      in

      if List.length params = 0 then
        (* No parameters - this is just a pattern match *)
        body_expr
      else Function { params = List.length params; body = body_expr }
  | Ppxlib.Pexp_let (_, bindings, body) ->
      let bindings =
        List.map
          (fun vb ->
            match vb.Ppxlib.pvb_pat.Ppxlib.ppat_desc with
            | Ppxlib.Ppat_var { txt; _ } ->
                (txt, ppxlib_expr_to_ast vb.Ppxlib.pvb_expr)
            | _ -> ("_", ppxlib_expr_to_ast vb.Ppxlib.pvb_expr))
          bindings
      in
      Let { bindings; body = ppxlib_expr_to_ast body }
  | Ppxlib.Pexp_sequence (e1, e2) ->
      Sequence [ ppxlib_expr_to_ast e1; ppxlib_expr_to_ast e2 ]
  | _ -> Other

(** Extract function definitions from structure items *)
let extract_functions_from_structure structure =
  let functions = ref [] in

  (* Use a visitor to find all value bindings *)
  let visitor =
    object
      inherit Ppxlib.Ast_traverse.iter

      method! value_binding vb =
        match vb.Ppxlib.pvb_pat.Ppxlib.ppat_desc with
        | Ppxlib.Ppat_var { txt = name; _ } ->
            Log.debug (fun m -> m "Processing binding: %s" name);
            let expr = ppxlib_expr_to_ast vb.pvb_expr in
            Log.debug (fun m -> m "Converted %s to AST" name);
            functions := (name, expr) :: !functions
        | _ -> ()
    end
  in

  visitor#structure structure;
  List.rev !functions

(** Extract functions from a source file using ppxlib *)
let extract_functions filename =
  try
    Log.debug (fun m -> m "Parsing file: %s" filename);
    let content = In_channel.with_open_text filename In_channel.input_all in
    let lexbuf = Lexing.from_string content in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };

    (* Check if it's an interface file *)
    if Filename.check_suffix filename ".mli" then (
      (* Interface files don't contain function implementations *)
      Log.debug (fun m -> m "Skipping interface file: %s" filename);
      [])
    else
      let structure = Ppxlib.Parse.implementation lexbuf in
      let functions = extract_functions_from_structure structure in

      Log.debug (fun m ->
          m "Extracted %d functions from %s" (List.length functions) filename);
      functions
  with exn ->
    Log.err (fun m ->
        m "Failed to parse %s: %s" filename (Printexc.to_string exn));
    []

(** Standard functions for type t *)
let equal a b = a.functions = b.functions

let compare a b = compare a.functions b.functions

let pp ppf t =
  Fmt.pf ppf "@[<v>{ functions = %a }@]" 
    (Fmt.list ~sep:Fmt.comma (Fmt.pair ~sep:(Fmt.any " -> ") Fmt.string Fmt.nop))
    t.functions
