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
let extract_quoted_string line =
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

(* All the parsing functions continue here... I'll add them systematically *)

(** Parse AST text with specific what (for testing) *)
let text what input =
  (* Phase 1: Lex the text into tokens *)
  let tokens = lex_text ~parse_loc_from_line:true input in
  (* Phase 2: Build indentation-based tree *)
  let trees = build_tree_from_tokens tokens in
  (* Phase 3: Transform tree to AST *)
  let rec transform_tree_to_ast what trees =
    List.fold_left
      (fun acc tree -> merge_ast acc (process_tree what tree))
      empty_acc trees
  and process_tree what (Node (token, children)) =
    let raw_node_type = get_node_type token.content in
    (* Check if we need to switch what for children *)
    let child_what =
      if raw_node_type = "Tstr_attribute" then Parsetree else what
    in
    let node_type = normalize_node_type what raw_node_type in
    Log.debug (fun m ->
        m "process_tree: raw=%s normalized=%s what=%s child_what=%s children=%d"
          raw_node_type node_type
          (match what with
          | Parsetree -> "Parsetree"
          | Typedtree -> "Typedtree")
          (match child_what with
          | Parsetree -> "Parsetree"
          | Typedtree -> "Typedtree")
          (List.length children));

    (* Comprehensive parsing logic *)
    match node_type with
    | "exp_ident" ->
        (* Extract identifier name from content *)
        let name =
          match extract_quoted_string token.content with
          | Some n ->
              let parsed = parse_name n in
              if parsed.base = "*type-error*" then raise Type_error else parsed
          | None -> { prefix = []; base = token.content }
        in
        { empty_acc with identifiers = [ { name; location = token.loc } ] }
    | "pat_var" ->
        (* Extract pattern variable name *)
        let name =
          match extract_quoted_string token.content with
          | Some n -> parse_name n
          | None -> { prefix = []; base = token.content }
        in
        { empty_acc with patterns = [ { name; location = token.loc } ] }
    | "str_value" ->
        (* Value binding - look for function definitions *)
        let child_ast = transform_tree_to_ast child_what children in
        let functions =
          extract_functions_from_value_binding child_what children
        in
        merge_ast child_ast { empty_acc with functions }
    | "str_eval" ->
        (* Structure item evaluation (e.g., attributes) - just process children *)
        transform_tree_to_ast child_what children
    | "str_attribute" ->
        (* Structure item attribute - just process children *)
        transform_tree_to_ast child_what children
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
        let child_ast = transform_tree_to_ast child_what children in
        { empty_acc with types = child_ast.types }
    | "type_declaration" ->
        (* Extract type name from content *)
        let name =
          match extract_quoted_string token.content with
          | Some n -> parse_name n
          | None -> { prefix = []; base = token.content }
        in
        { empty_acc with types = [ { name; location = token.loc } ] }
    | "[" ->
        (* Array/list node - often contains value bindings *)
        Log.debug (fun m ->
            m
              "Processing [ node with what=%s, passing child_what=%s to \
               children"
              (match what with
              | Parsetree -> "Parsetree"
              | Typedtree -> "Typedtree")
              (match child_what with
              | Parsetree -> "Parsetree"
              | Typedtree -> "Typedtree"));
        let functions = extract_functions_from_bracket_node what children in
        let child_ast = transform_tree_to_ast child_what children in
        merge_ast child_ast { empty_acc with functions }
    | "structure_item" ->
        (* Process structure items *)
        transform_tree_to_ast child_what children
    | _ ->
        (* Process children for unhandled node types *)
        transform_tree_to_ast child_what children
  and extract_functions_from_value_binding what nodes =
    (* Look for function definitions in value bindings *)
    List.fold_left
      (fun acc node ->
        match node with
        | Node (token, children) ->
            let node_type = get_node_type token.content in
            if node_type = "<def>" then
              match extract_function_from_def what children with
              | Some func -> func :: acc
              | None -> acc
            else acc)
      [] nodes
    |> List.rev
  and extract_functions_from_bracket_node what nodes =
    (* Extract functions from bracket nodes *)
    List.fold_left
      (fun acc node ->
        match node with
        | Node (token, children) ->
            let node_type = get_node_type token.content in
            if node_type = "<def>" then
              match extract_function_from_def what children with
              | Some func -> func :: acc
              | None -> acc
            else acc)
      [] nodes
    |> List.rev
  and extract_function_from_def what nodes =
    (* Extract function from <def> node *)
    let rec find_pattern_and_expr nodes pattern_name expr_node =
      match nodes with
      | [] -> (pattern_name, expr_node)
      | Node (token, children) :: rest -> (
          let raw_node_type = get_node_type token.content in
          let node_type = normalize_node_type what raw_node_type in
          match node_type with
          | "pattern" ->
              (* Extract the name from the pattern *)
              let name = extract_name_from_pattern what children in
              find_pattern_and_expr rest name expr_node
          | "expression" ->
              (* Check if this expression is a function *)
              let expr = extract_expr_if_function what children in
              find_pattern_and_expr rest pattern_name expr
          | _ -> find_pattern_and_expr rest pattern_name expr_node)
    in
    let pattern_name, expr_node = find_pattern_and_expr nodes None None in
    match (pattern_name, expr_node) with
    | Some name, Some expr -> Some (name, expr)
    | _ -> None
  and extract_name_from_pattern what nodes =
    (* Extract name from pattern nodes *)
    List.find_map
      (fun node ->
        match node with
        | Node (token, _) ->
            let raw_node_type = get_node_type token.content in
            let node_type = normalize_node_type what raw_node_type in
            if node_type = "pat_var" then
              match extract_quoted_string token.content with
              | Some n -> Some (parse_name n).base
              | None -> None
            else None)
      nodes
  and extract_expr_if_function what nodes =
    (* Check if expression is a function *)
    let rec find_function_in_nodes nodes =
      match nodes with
      | [] -> None
      | Node (token, _) :: rest ->
          let raw_node_type = get_node_type token.content in
          let node_type = normalize_node_type what raw_node_type in
          Log.debug (fun m ->
              m "extract_expr_if_function: checking node_type=%s" node_type);
          if node_type = "exp_function" || node_type = "exp_fun" then
            (* Found function marker, now extract body from siblings *)
            Some (extract_function_expr what rest)
          else find_function_in_nodes rest
    in
    find_function_in_nodes nodes
  and extract_function_expr what children =
    (* Extract function expression body *)
    let body = find_function_body what children in
    Log.debug (fun m ->
        m "extract_function_expr: body=%s"
          (match body with
          | If_then_else _ -> "If_then_else"
          | Match _ -> "Match"
          | Try _ -> "Try"
          | Other -> "Other"
          | _ -> "unknown"));
    Function { params = 1; body }
  and find_function_body what nodes =
    (* Find the function body in children *)
    Log.debug (fun m ->
        m "find_function_body: searching in %d nodes" (List.length nodes));
    match nodes with
    | [] -> Other
    | Node (token, children) :: rest -> (
        let raw_node_type = get_node_type token.content in
        let node_type = normalize_node_type what raw_node_type in
        Log.debug (fun m ->
            m "find_function_body: checking node_type=%s" node_type);
        match node_type with
        | "function_body" -> (
            (* Found the function body *)
            Log.debug (fun m ->
                m "find_function_body: found function_body with %d children"
                  (List.length children));
            match children with
            | [] -> Other
            | expr_node :: _ -> extract_expr_from_tree what expr_node)
        | "exp_match" ->
            (* Match expression - siblings are the matched expr and cases *)
            extract_match_expr_from_siblings what rest
        | "exp_ifthenelse" | "exp_if" ->
            (* If-then-else expression - siblings are condition, then, else *)
            extract_if_expr_from_siblings what rest
        | "exp_try" ->
            (* Try expression - siblings are expr and handlers *)
            extract_try_expr_from_siblings what rest
        | "exp_let" ->
            (* Let expression - siblings are bindings and body *)
            extract_let_expr_from_siblings what rest
        | "expression" ->
            (* Generic expression *)
            extract_expr_from_tree what (Node (token, children))
        | "exp_fun" -> (
            (* Parsetree function - last child is the body *)
            match List.rev rest with
            | body_node :: _ -> extract_expr_from_tree what body_node
            | [] -> Other)
        | _ ->
            (* Try children, then siblings *)
            let child_result = find_function_body what children in
            if child_result = Other then find_function_body what rest
            else child_result)
  and extract_expr_from_tree what (Node (token, children)) =
    (* Extract expression from tree node *)
    let raw_node_type = get_node_type token.content in
    let node_type = normalize_node_type what raw_node_type in
    match node_type with
    | "exp_ident" ->
        let name =
          match extract_quoted_string token.content with
          | Some n -> n
          | None -> token.content
        in
        Ident name
    | "exp_constant" ->
        let value = extract_constant_value token children in
        Constant value
    | "exp_match" ->
        (* Siblings contain the matched expr and cases *)
        extract_match_expr_from_siblings what children
    | "exp_ifthenelse" | "exp_if" ->
        (* Siblings contain condition, then, and else branches *)
        extract_if_expr_from_siblings what children
    | "exp_try" ->
        (* Siblings contain the try expr and exception handlers *)
        extract_try_expr_from_siblings what children
    | "exp_let" ->
        (* Siblings contain bindings and body *)
        extract_let_expr_from_siblings what children
    | "expression" -> (
        (* Generic expression node - check first child for actual type *)
        match children with
        | [] -> Other
        | Node (child_token, _) :: siblings -> (
            let child_raw = get_node_type child_token.content in
            let child_type = normalize_node_type what child_raw in
            match child_type with
            | "exp_ifthenelse" | "exp_if" ->
                extract_if_expr_from_siblings what siblings
            | "exp_match" -> extract_match_expr_from_siblings what siblings
            | "exp_try" -> extract_try_expr_from_siblings what siblings
            | "exp_let" -> extract_let_expr_from_siblings what siblings
            | _ -> extract_expr_from_tree what (List.hd children)))
    | _ -> Other
  and extract_constant_value token children =
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
          match extract_quoted_string token.content with
          | Some v -> v
          | None -> "constant")
  and extract_match_expr_from_siblings what siblings =
    (* Extract match expression from sibling nodes *)
    match siblings with
    | expr_node :: rest ->
        let expr = extract_expr_from_tree what expr_node in
        let case_count = count_cases rest in
        Match { expr; cases = max 1 case_count }
    | [] -> Match { expr = Other; cases = 0 }
  and extract_if_expr_from_siblings what siblings =
    (* Extract if-then-else expression from sibling nodes *)
    match siblings with
    | cond_node :: then_node :: rest ->
        let cond = extract_expr_from_tree what cond_node in
        let then_expr = extract_expr_from_tree what then_node in
        let else_expr =
          match rest with
          | else_node :: _ -> Some (extract_expr_from_tree what else_node)
          | [] -> None
        in
        If_then_else { cond; then_expr; else_expr }
    | _ -> If_then_else { cond = Other; then_expr = Other; else_expr = None }
  and extract_try_expr_from_siblings what siblings =
    (* Extract try expression from sibling nodes *)
    match siblings with
    | expr_node :: rest ->
        let expr = extract_expr_from_tree what expr_node in
        let handler_count = count_cases rest in
        Try { expr; handlers = max 0 handler_count }
    | [] -> Try { expr = Other; handlers = 0 }
  and extract_let_expr_from_siblings what siblings =
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
                let bindings = extract_let_bindings children in
                find_bindings_and_body rest (bindings_acc @ bindings)
              else if node_type = "expression" then
                (* This is the body *)
                ( bindings_acc,
                  extract_expr_from_tree what (Node (token, children)) )
              else find_bindings_and_body rest bindings_acc
        in
        let bindings, body = find_bindings_and_body rest [] in
        Let { bindings; body }
    | [] -> Let { bindings = []; body = Other }
  and extract_let_bindings _nodes =
    (* Extract bindings from let expression - for now return empty list *)
    []
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
  transform_tree_to_ast what trees

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
