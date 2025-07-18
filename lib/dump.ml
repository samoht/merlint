(** Dump module - handles all AST text dump parsing functionality *)

let src = Logs.Src.create "merlint.dump" ~doc:"AST dump parsing"

module Log = (val Logs.src_log src : Logs.LOG)
open Ast

type token = { indent : int; content : string; loc : Location.t option }
(** Phase 1: Token type for lexing *)

(** Phase 2: Generic tree structure for indentation-based parsing *)
type 'a tree = Node of 'a * 'a tree list

(** Empty accumulator for AST construction *)
let empty_acc =
  {
    expressions = [];
    functions = [];
    modules = [];
    types = [];
    exceptions = [];
    variants = [];
    identifiers = [];
    patterns = [];
  }

(** Helper regex components for location parsing *)
let filename = Re.rep1 (Re.compl [ Re.char '[' ])

let number = Re.rep1 Re.digit

let location_part =
  Re.seq
    [
      Re.str "[";
      Re.group number;
      Re.str ",";
      number;
      Re.str "+";
      Re.group number;
      Re.str "]";
    ]

let loc_regex =
  Re.compile
    (Re.seq
       [
         Re.str "(";
         Re.group filename;
         location_part;
         Re.str "..";
         filename;
         location_part;
         Re.str ")";
       ])

let parse_location str =
  try
    let m = Re.exec loc_regex str in
    let file = Re.Group.get m 1 in
    let start_line = int_of_string (Re.Group.get m 2) in
    let start_col = int_of_string (Re.Group.get m 3) in
    let end_line = int_of_string (Re.Group.get m 4) in
    let end_col = int_of_string (Re.Group.get m 5) in
    Some (Location.create ~file ~start_line ~start_col ~end_line ~end_col)
  with Not_found -> None

(** Parse line indentation - counts leading spaces *)
let parse_indent line =
  let len = String.length line in
  let rec count_spaces i =
    if i < len && line.[i] = ' ' then count_spaces (i + 1) else i
  in
  count_spaces 0

(** Phase 1: Lexer - Convert raw text to tokens *)
let lex_text ?(parse_loc_from_line = true) text : token list =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let len = String.length line in
         if len = 0 then None
         else
           let indent = parse_indent line in
           let trimmed = String.trim line in
           if trimmed = "" then None
           else
             let loc =
               if parse_loc_from_line then parse_location line else None
             in
             Some { indent; content = trimmed; loc })

(** Extract node type from token content *)
let get_node_type content =
  match String.index_opt content ' ' with
  | Some idx -> String.sub content 0 idx
  | None -> content

(** Check if a node type is an attribute that should include the next bracket as
    payload *)
let is_attribute_node content =
  let node_type = get_node_type content in
  String.ends_with ~suffix:"attribute" node_type

(** Phase 2: Build indentation-based tree from tokens *)
let rec build_tree_from_tokens tokens : token tree list =
  match tokens with
  | [] -> []
  | head :: tail ->
      let current_indent = head.indent in

      (* Helper function to collect all direct children of a node *)
      let collect_children parent_indent tokens =
        let rec aux acc remaining =
          match remaining with
          | [] -> (List.rev acc, [])
          | t :: rest ->
              if t.indent > parent_indent then aux (t :: acc) rest
              else (List.rev acc, remaining)
        in
        let child_tokens, sibling_tokens = aux [] tokens in
        (build_tree_from_tokens child_tokens, sibling_tokens)
      in

      let children, siblings =
        if is_attribute_node head.content then
          match tail with
          | bracket :: rest
            when bracket.indent = current_indent
                 && String.trim bracket.content = "[" ->
              (* The bracket is the child, and its children must be parsed recursively *)
              let bracket_children, remaining_siblings =
                collect_children bracket.indent rest
              in
              ([ Node (bracket, bracket_children) ], remaining_siblings)
          | _ ->
              (* No bracket payload, normal child collection *)
              collect_children current_indent tail
        else
          (* Normal node processing *)
          collect_children current_indent tail
      in

      let current_tree = Node (head, children) in
      current_tree :: build_tree_from_tokens siblings

(** Extract content between quotes (useful for parsing AST dumps) *)
let quoted_string line =
  let quote_regex =
    Re.compile
      (Re.seq
         [
           Re.str "\"";
           Re.group (Re.rep (Re.compl [ Re.char '"' ]));
           Re.str "\"";
         ])
  in
  try
    let m = Re.exec quote_regex line in
    Some (Re.Group.get m 1)
  with Not_found -> None

(** Parse structured name from string like "Str.regexp" or "Stdlib!.Obj.magic"
*)
let parse_name str =
  (* Remove unique suffix like /123 if present *)
  let str =
    match String.index_opt str '/' with
    | Some i -> String.sub str 0 i
    | None -> str
  in
  (* Remove ! markers from stdlib names *)
  let str = String.map (fun c -> if c = '!' then '.' else c) str in
  (* Split by . to get components *)
  let parts = String.split_on_char '.' str in
  match List.rev parts with
  | [] -> { prefix = []; base = "" }
  | base :: rev_modules -> { prefix = List.rev rev_modules; base }

(** Normalize node type based on what *)
let normalize_node_type (what : what) (node_type : string) : string =
  (* Special cases that don't follow P/T convention *)
  match node_type with
  | "Param_pat" | "Nolabel" | "Nonrec" | "Rec" | "Optional" | "Labelled"
  | "Some" | "None" | "Const_int" | "Const_string" | "Const_float"
  | "type_declaration" | "attribute" | "structure_item" ->
      node_type
  | _ -> (
      if String.length node_type < 2 then node_type
      else
        let prefix = node_type.[0] in
        match (prefix, what) with
        | 'T', Typedtree | 'P', Parsetree ->
            (* Correct prefix for the what, so we strip it. *)
            String.sub node_type 1 (String.length node_type - 1)
        | 'P', Typedtree ->
            (* This shouldn't happen - raise error *)
            let error_msg =
              Printf.sprintf
                "Found Parsetree node '%s' while parsing for Typedtree."
                node_type
            in
            raise (Parse_error error_msg)
        | 'T', Parsetree ->
            (* This shouldn't happen - raise error *)
            let error_msg =
              Printf.sprintf
                "Found Typedtree node '%s' while parsing for Parsetree."
                node_type
            in
            raise (Parse_error error_msg)
        | _ ->
            (* Not a P or T node, so return it as is *)
            node_type)

(* Helper functions *)

(** Parse a name from token content *)
let parsed_name token =
  match quoted_string token.content with
  | Some n -> parse_name n
  | None -> { prefix = []; base = token.content }

(** Pretty-print what for debugging *)
let pp_what ppf = function
  | Parsetree -> Fmt.string ppf "Parsetree"
  | Typedtree -> Fmt.string ppf "Typedtree"

(* All the parsing functions continue here... I'll add them systematically *)

(** Parse AST text with specific what (for testing) *)
let text what input =
  (* Phase 1: Lex the text into tokens *)
  let tokens = lex_text ~parse_loc_from_line:true input in
  (* Phase 2: Build indentation-based tree *)
  let trees = build_tree_from_tokens tokens in
  (* Phase 3: Transform tree to AST *)
  let rec ast_of_trees what trees =
    List.fold_left
      (fun acc tree -> merge_ast acc (ast_of_tree what tree))
      empty_acc trees
  and ast_of_tree what (Node (token, children)) =
    let raw_node_type = get_node_type token.content in
    (* Check if we need to switch what for children *)
    let child_what =
      if raw_node_type = "Tstr_attribute" then Parsetree else what
    in
    let node_type = normalize_node_type what raw_node_type in
    Log.debug (fun m ->
        m "process_tree: raw=%s normalized=%s what=%a child_what=%a children=%d"
          raw_node_type node_type pp_what what pp_what child_what
          (List.length children));

    (* Comprehensive parsing logic *)
    match node_type with
    | "exp_ident" ->
        (* Extract identifier name from content *)
        let name = parsed_name token in
        if name.base = "*type-error*" then raise Type_error;
        { empty_acc with identifiers = [ { name; location = token.loc } ] }
    | "pat_var" ->
        (* Extract pattern variable name *)
        let name = parsed_name token in
        { empty_acc with patterns = [ { name; location = token.loc } ] }
    | "str_value" | "[" ->
        (* Value binding or bracket node - look for function definitions *)
        let child_ast = ast_of_trees child_what children in
        let functions = functions child_what children in
        merge_ast child_ast { empty_acc with functions }
    | "str_eval" | "str_attribute" ->
        (* Structure item evaluation/attribute - just process children *)
        ast_of_trees child_what children
    | "str_module" ->
        (* Extract module name *)
        let name =
          match children with
          | Node (child, _) :: _ -> parse_name (String.trim child.content)
          | [] -> { prefix = []; base = "Unknown" }
        in
        { empty_acc with modules = [ { name; location = token.loc } ] }
    | "str_type" ->
        (* Extract type name *)
        let child_ast = ast_of_trees child_what children in
        { empty_acc with types = child_ast.types }
    | "type_declaration" ->
        (* Extract type name from content *)
        let name = parsed_name token in
        { empty_acc with types = [ { name; location = token.loc } ] }
    | "structure_item" | _ ->
        (* Process children for structure items and unhandled node types *)
        ast_of_trees child_what children
  and functions what nodes =
    (* Look for function definitions in nodes *)
    List.fold_left
      (fun acc node ->
        match node with
        | Node (token, children) ->
            let node_type = get_node_type token.content in
            if node_type = "<def>" then
              match function_from_def what children with
              | Some func -> func :: acc
              | None -> acc
            else acc)
      [] nodes
    |> List.rev
  and def_expr what nodes =
    (* Extract pattern name and expression from <def> node *)
    let rec find_pattern_and_expr nodes pattern_name_opt expr_node =
      match nodes with
      | [] -> (pattern_name_opt, expr_node)
      | (Node (token, children) as node) :: rest -> (
          let raw_node_type = get_node_type token.content in
          let node_type = normalize_node_type what raw_node_type in
          match node_type with
          | "pattern" ->
              (* Extract the name from the pattern *)
              let name = pattern_name what children in
              find_pattern_and_expr rest name expr_node
          | "expression" ->
              (* Extract the expression - check if it's a function first *)
              let expr =
                match maybe_function what [ node ] with
                | Some func_expr -> Some func_expr
                | None -> Some (expr_of_tree what node)
              in
              find_pattern_and_expr rest pattern_name_opt expr
          | _ -> find_pattern_and_expr rest pattern_name_opt expr_node)
    in
    let pattern_name_opt, expr_node = find_pattern_and_expr nodes None None in
    match (pattern_name_opt, expr_node) with
    | Some name, Some expr -> Some (name, expr)
    | _ -> None
  and function_from_def what nodes =
    (* Extract function from <def> node *)
    match def_expr what nodes with
    | Some (name, expr) -> (
        (* Check if the expression is a function *)
        match expr with
        | Function _ -> Some (name, expr)
        | _ -> None)
    | None -> None
  and binding_from_def what nodes =
    (* Extract binding (name, expr) from a <def> node *)
    def_expr what nodes
  and pattern_name what nodes =
    (* Extract name from pattern nodes *)
    List.find_map
      (fun node ->
        match node with
        | Node (token, _) ->
            let raw_node_type = get_node_type token.content in
            let node_type = normalize_node_type what raw_node_type in
            if node_type = "pat_var" then
              match quoted_string token.content with
              | Some n -> Some (parse_name n).base
              | None -> None
            else None)
      nodes
  and maybe_function what nodes =
    (* Check if expression is a function *)
    let rec find_function_in_nodes nodes =
      match nodes with
      | [] -> None
      | Node (token, children) :: rest ->
          let raw_node_type = get_node_type token.content in
          let node_type = normalize_node_type what raw_node_type in
          Log.debug (fun m -> m "as_function: checking node_type=%s" node_type);
          if node_type = "exp_function" || node_type = "exp_fun" then
            (* Found function marker, now extract body from siblings *)
            Some (function_body what rest)
          else if node_type = "expression" then
            (* For expression nodes, check their children *)
            find_function_in_nodes children
          else find_function_in_nodes rest
    in
    find_function_in_nodes nodes
  and function_body what children =
    (* Extract function expression body *)
    Log.debug (fun m ->
        m "function_expr: called with %d children" (List.length children));
    let body =
      (* Look for function_body node or process children directly *)
      let rec find_body nodes =
        match nodes with
        | [] -> Other
        | Node (token, children) :: rest ->
            let raw_node_type = get_node_type token.content in
            let node_type = normalize_node_type what raw_node_type in
            Log.debug (fun m ->
                m "function_expr.find_body: node_type=%s" node_type);
            if node_type = "function_body" then (
              (* Found function body, extract expression from its children *)
              Log.debug (fun m ->
                  m
                    "function_expr.find_body: found function_body with %d \
                     children"
                    (List.length children));
              (* Debug: print what's in the children *)
              List.iteri
                (fun i child ->
                  match child with
                  | Node (tok, _) ->
                      Log.debug (fun m ->
                          m "function_expr.find_body: child[%d] = %s" i
                            tok.content))
                children;
              expr_of_nodes what children)
            else if node_type = "expression" then
              (* Direct expression *)
              expr_of_tree what (Node (token, children))
            else
              (* Try siblings *)
              find_body rest
      in
      find_body children
    in
    Log.debug (fun m ->
        m "function_expr: body=%s"
          (match body with
          | If_then_else _ -> "If_then_else"
          | Match _ -> "Match"
          | Try _ -> "Try"
          | Other -> "Other"
          | _ -> "unknown"));
    Function { params = 1; body }
  and expr_of_tree what (Node (token, children)) =
    (* Extract expression from tree node *)
    let raw_node_type = get_node_type token.content in
    let node_type = normalize_node_type what raw_node_type in
    match node_type with
    | "exp_ident" ->
        let name =
          match quoted_string token.content with
          | Some n -> n
          | None -> token.content
        in
        Ident name
    | "exp_constant" -> Constant (constant token children)
    | "exp_match" ->
        (* Siblings contain the matched expr and cases *)
        match_expr what children
    | "exp_ifthenelse" | "exp_if" ->
        (* Siblings contain condition, then, and else branches *)
        if_expr what children
    | "exp_try" ->
        (* Siblings contain the try expr and exception handlers *)
        try_expr what children
    | "exp_let" ->
        (* Siblings contain bindings and body *)
        let_expr what children
    | "expression" -> (
        (* For expression nodes, check if there's a single child we can process directly *)
        match children with
        | [ child ] -> expr_of_tree what child
        | _ -> expr_of_nodes what children)
    | _ -> Other
  and expr_of_nodes what children =
    (* Extract expression from children, skipping attributes *)
    let rec find_expr nodes =
      match nodes with
      | [] -> Other
      | (Node (token, node_children) as node) :: siblings -> (
          let raw_node_type = get_node_type token.content in
          let node_type = normalize_node_type what raw_node_type in
          Log.debug (fun m ->
              m "expr_of_children: checking node_type=%s with %d children"
                node_type
                (List.length node_children));
          match node_type with
          | "attribute" -> find_expr siblings (* Skip attributes *)
          | "exp_ifthenelse" | "exp_if" ->
              (* For if expressions, children are the condition, then, else *)
              if_expr what siblings
          | "exp_match" -> match_expr what siblings
          | "exp_try" -> try_expr what siblings
          | "exp_let" -> let_expr what siblings
          | "exp_constant" -> expr_of_tree what node
          | "exp_ident" -> expr_of_tree what node
          | "expression" ->
              expr_of_tree what node (* Process expression nodes *)
          | _ ->
              find_expr
                siblings (* Try siblings if current node doesn't match *))
    in
    find_expr children
  and constant token children =
    (* Extract constant value from token or children *)
    if List.length children > 0 then
      (* Parsetree format *)
      match children with
      | Node (const_token, _) :: _ ->
          let const_content = const_token.content in
          if String.contains const_content '(' then
            (* Extract from PConst_int (42,None) format *)
            let parts = String.split_on_char '(' const_content in
            match parts with
            | _ :: value_part :: _ -> (
                let comma_parts = String.split_on_char ',' value_part in
                match comma_parts with v :: _ -> v | _ -> "constant")
            | _ -> "constant"
          else "constant"
      | _ -> "constant"
    else
      (* Typedtree format *)
      let parts = String.split_on_char ' ' token.content in
      match parts with
      | _ :: "Const_int" :: v :: _ -> v
      | _ :: "Const_string" :: rest -> String.concat " " rest
      | _ :: "Const_float" :: v :: _ -> v
      | _ -> (
          match quoted_string token.content with
          | Some v -> v
          | None -> "constant")
  and match_expr what siblings =
    (* Extract match expression from sibling nodes *)
    match siblings with
    | expr_node :: rest ->
        let expr = expr_of_tree what expr_node in
        let case_count = count_cases rest in
        Match { expr; cases = max 1 case_count }
    | [] -> Match { expr = Other; cases = 0 }
  and if_expr what siblings =
    (* Extract if-then-else expression from sibling nodes *)
    Log.debug (fun m -> m "if_expr: %d siblings" (List.length siblings));
    match siblings with
    | cond_node :: then_node :: rest ->
        let cond = expr_of_tree what cond_node in
        let then_expr = expr_of_tree what then_node in
        let else_expr =
          match rest with
          | else_node :: _ -> Some (expr_of_tree what else_node)
          | [] -> None
        in
        If_then_else { cond; then_expr; else_expr }
    | _ -> If_then_else { cond = Other; then_expr = Other; else_expr = None }
  and try_expr what siblings =
    (* Extract try expression from sibling nodes *)
    match siblings with
    | expr_node :: rest ->
        let expr = expr_of_tree what expr_node in
        let handler_count = count_cases rest in
        Try { expr; handlers = max 0 handler_count }
    | [] -> Try { expr = Other; handlers = 0 }
  and let_expr what siblings =
    (* Extract let expression from sibling nodes *)
    match siblings with
    | _ :: rest ->
        (* Skip the Nonrec/Rec flag, look for bindings in a [ node and body *)
        let rec find_bindings_and_body nodes bindings_acc =
          match nodes with
          | [] -> (bindings_acc, Other)
          | Node (token, children) :: rest ->
              let node_type = get_node_type token.content in
              if node_type = "[" then
                (* This contains the bindings *)
                let bindings = let_bindings what children in
                find_bindings_and_body rest (bindings_acc @ bindings)
              else if node_type = "expression" then
                (* This is the body *)
                (bindings_acc, expr_of_tree what (Node (token, children)))
              else find_bindings_and_body rest bindings_acc
        in
        let bindings, body = find_bindings_and_body rest [] in
        Let { bindings; body }
    | [] -> Let { bindings = []; body = Other }
  and let_bindings what nodes =
    (* Extract bindings from let expression *)
    List.fold_left
      (fun acc node ->
        match node with
        | Node (token, children) ->
            let node_type = get_node_type token.content in
            if node_type = "<def>" then
              (* Found a binding definition *)
              match binding_from_def what children with
              | Some binding -> binding :: acc
              | None -> acc
            else acc)
      [] nodes
    |> List.rev
  and count_cases children =
    (* Count case nodes - may be inside a [ node *)
    List.fold_left
      (fun count child ->
        match child with
        | Node (token, sub_children) ->
            let node_type = get_node_type token.content in
            if node_type = "case" then count + 1
            else if node_type = "[" then
              (* Cases might be inside a bracket node *)
              count + count_cases sub_children
            else count)
      0 children
  and merge_ast acc ast =
    {
      expressions = acc.expressions @ ast.expressions;
      functions = acc.functions @ ast.functions;
      modules = acc.modules @ ast.modules;
      types = acc.types @ ast.types;
      exceptions = acc.exceptions @ ast.exceptions;
      variants = acc.variants @ ast.variants;
      identifiers = acc.identifiers @ ast.identifiers;
      patterns = acc.patterns @ ast.patterns;
    }
  in
  ast_of_trees what trees

(** Parse parsetree text dump into AST structure *)
let parsetree input = text Parsetree input

(** Parse typedtree text dump into AST structure using three-phase approach *)
let typedtree input =
  (* Try Typedtree first, fall back to Parsetree if there are type errors *)
  try text Typedtree input
  with Type_error ->
    (* Type errors in the code - try with Parsetree what *)
    Log.debug (fun m -> m "Type errors detected, falling back to Parsetree");
    text Parsetree input
