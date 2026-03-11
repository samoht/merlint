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
  | List  (** List literals and array literals *)
  | Record of { fields : int }  (** Record literals with field count *)
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
    | List | Record _ | Other -> empty

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

  let equal = ( = )

  let pp ppf info =
    Fmt.pf ppf
      "{ total = %d; if_then_else = %d; match_cases = %d; try_handlers = %d; \
       boolean_operators = %d }"
      info.total info.if_then_else info.match_cases info.try_handlers
      info.boolean_operators
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
      | List | Record _ | Other -> current_depth
    in
    depth_of 0 node
end

(** Count fields in a trailing record literal. Walks down the "tail" of the
    expression (body of let, else branch of if-then-else, last element of
    sequence) looking for a Record at the end. Returns the field count, or 0 if
    the tail isn't a record. *)
let rec trailing_record_fields = function
  | Record { fields } -> fields
  | Let { body; _ } -> trailing_record_fields body
  | Sequence exprs -> (
      match List.rev exprs with
      | last :: _ -> trailing_record_fields last
      | [] -> 0)
  | If_then_else { else_expr = Some e; _ } -> trailing_record_fields e
  | If_then_else { then_expr; else_expr = None } ->
      trailing_record_fields then_expr
  | Try { expr; _ } -> trailing_record_fields expr
  | Function { body; _ } -> trailing_record_fields body
  | Match _ | List | Other -> 0

(** Pretty-print expression for debugging *)
let expr_to_string (expr : Parsetree.expression) =
  Fmt.str "%a" Pprintast.expression expr

(** Convert Parsetree expression to our AST representation *)
let rec parsetree_expr_to_ast (expr : Parsetree.expression) : expr =
  Log.debug (fun m -> m "parsetree_expr_to_ast: %s" (expr_to_string expr));
  Log.debug (fun m ->
      m "Expression type: %s"
        (match expr.pexp_desc with
        | Pexp_ifthenelse _ -> "Pexp_ifthenelse"
        | Pexp_match _ -> "Pexp_match"
        | Pexp_try _ -> "Pexp_try"
        | Pexp_function _ -> "Pexp_function"
        | Pexp_let _ -> "Pexp_let"
        | Pexp_sequence _ -> "Pexp_sequence"
        | _ -> "Other"));
  match expr.pexp_desc with
  | Pexp_ifthenelse (cond, then_expr, else_expr) ->
      If_then_else
        {
          cond = parsetree_expr_to_ast cond;
          then_expr = parsetree_expr_to_ast then_expr;
          else_expr = Option.map parsetree_expr_to_ast else_expr;
        }
  | Pexp_match (expr, cases) ->
      Match { expr = parsetree_expr_to_ast expr; cases = List.length cases }
  | Pexp_try (expr, cases) ->
      Try { expr = parsetree_expr_to_ast expr; handlers = List.length cases }
  | Pexp_function (params, _, body) ->
      (* In OCaml 5, multi-parameter functions have all params here *)
      Log.debug (fun m -> m "Pexp_function: %d params" (List.length params));

      let body_expr =
        match body with
        | Pfunction_body expr ->
            Log.debug (fun m -> m "Found Pfunction_body");
            parsetree_expr_to_ast expr
        | Pfunction_cases (cases, _, _) ->
            Log.debug (fun m ->
                m "Found Pfunction_cases with %d cases" (List.length cases));
            (* This is a pattern matching function - treat it as a match expression *)
            Match { expr = Other; cases = List.length cases }
      in

      if List.length params = 0 then
        (* No parameters - this is just a pattern match *)
        body_expr
      else Function { params = List.length params; body = body_expr }
  | Pexp_let (_, bindings, body) ->
      let bindings =
        List.map
          (fun (vb : Parsetree.value_binding) ->
            match vb.pvb_pat.ppat_desc with
            | Ppat_var { txt; _ } -> (txt, parsetree_expr_to_ast vb.pvb_expr)
            | _ -> ("_", parsetree_expr_to_ast vb.pvb_expr))
          bindings
      in
      Let { bindings; body = parsetree_expr_to_ast body }
  | Pexp_sequence (e1, e2) ->
      Sequence [ parsetree_expr_to_ast e1; parsetree_expr_to_ast e2 ]
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> List (* Empty list *)
  | Pexp_construct ({ txt = Lident "::"; _ }, Some _) -> List (* List cons *)
  | Pexp_construct (_, Some arg) ->
      parsetree_expr_to_ast arg (* Ok/Some/constructor wrapping *)
  | Pexp_array _ -> List (* Array literal *)
  | Pexp_record (fields, _) ->
      Record { fields = List.length fields } (* Record literal *)
  | Pexp_apply (func, args) ->
      (* Parse function applications to find nested pattern matches *)
      Log.debug (fun m -> m "Pexp_apply with %d args" (List.length args));
      let func_ast = parsetree_expr_to_ast func in
      let args_asts =
        List.map (fun (_, arg) -> parsetree_expr_to_ast arg) args
      in
      (* Treat the whole apply as a sequence containing func and all args *)
      Sequence (func_ast :: args_asts)
  | Pexp_open (_, body) -> parsetree_expr_to_ast body (* let open M in expr *)
  | _ -> Other

(** Extract function definitions from structure items *)
let extract_functions_from_structure (structure : Parsetree.structure) =
  let functions = ref [] in

  let rec process_structure_item (item : Parsetree.structure_item) =
    match item.pstr_desc with
    | Pstr_value (_, bindings) ->
        List.iter
          (fun (vb : Parsetree.value_binding) ->
            match vb.pvb_pat.ppat_desc with
            | Ppat_var { txt = name; _ } ->
                Log.debug (fun m -> m "Processing binding: %s" name);
                let expr = parsetree_expr_to_ast vb.pvb_expr in
                Log.debug (fun m -> m "Converted %s to AST" name);
                functions := (name, expr) :: !functions
            | _ -> ())
          bindings
    | Pstr_module { pmb_expr; _ } -> process_module_expr pmb_expr
    | Pstr_recmodule mods ->
        List.iter
          (fun { Parsetree.pmb_expr; _ } -> process_module_expr pmb_expr)
          mods
    | _ -> ()
  and process_module_expr (me : Parsetree.module_expr) =
    match me.pmod_desc with
    | Pmod_structure structure -> List.iter process_structure_item structure
    | _ -> ()
  in

  List.iter process_structure_item structure;
  List.rev !functions

(** Extract functions from a source file using compiler-libs *)
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
      let structure = Parse.implementation lexbuf in
      let functions = extract_functions_from_structure structure in

      Log.debug (fun m ->
          m "Extracted %d functions from %s" (List.length functions) filename);
      functions
  with exn ->
    Log.err (fun m ->
        m "Failed to parse %s: %s" filename (Printexc.to_string exn));
    []

let rec pp_expr ppf = function
  | If_then_else { cond; then_expr; else_expr } ->
      Fmt.pf ppf "If(%a, %a, %a)" pp_expr cond pp_expr then_expr
        (Fmt.option pp_expr) else_expr
  | Match { cases; _ } -> Fmt.pf ppf "Match(%d)" cases
  | Try { expr; handlers } -> Fmt.pf ppf "Try(%a, %d)" pp_expr expr handlers
  | Function { params; body } -> Fmt.pf ppf "Fun(%d, %a)" params pp_expr body
  | Let { bindings; body } ->
      Fmt.pf ppf "Let([%a], %a)"
        (Fmt.list ~sep:Fmt.comma (fun ppf (n, e) ->
             Fmt.pf ppf "%s=%a" n pp_expr e))
        bindings pp_expr body
  | Sequence exprs ->
      Fmt.pf ppf "Seq[%a]" (Fmt.list ~sep:Fmt.comma pp_expr) exprs
  | List -> Fmt.pf ppf "List"
  | Record { fields } -> Fmt.pf ppf "Record(%d)" fields
  | Other -> Fmt.pf ppf "Other"

(** Standard functions for type t *)
let equal a b = a.functions = b.functions

let compare a b = compare a.functions b.functions

let pp ppf t =
  Fmt.pf ppf "@[<v>{ functions = %a }@]"
    (Fmt.list ~sep:Fmt.comma
       (Fmt.pair ~sep:(Fmt.any " -> ") Fmt.string Fmt.nop))
    t.functions
