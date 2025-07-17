(** Core AST types for expression analysis *)

type name = { prefix : string list; base : string }
type elt = { name : name; location : Location.t option }

type expr_node =
  | Construct of { name : string; args : expr_node list }
  | Apply of { func : expr_node; args : expr_node list }
  | Ident of string
  | Constant of string
  | If_then_else of {
      cond : expr_node;
      then_expr : expr_node;
      else_expr : expr_node option;
    }
  | Match of { expr : expr_node; cases : int }
  | Try of { expr : expr_node; handlers : int }
  | Function of { params : int; body : expr_node }
  | Let of { bindings : (string * expr_node) list; body : expr_node }
  | Sequence of expr_node list
  | Other

type t = {
  expressions : expr_node list;
  functions : (string * expr_node) list;
  modules : elt list;
  types : elt list;
  exceptions : elt list;
  variants : elt list;
  identifiers : elt list;
  patterns : elt list;
}

(** Generic visitor pattern for expr_node AST traversal *)
class visitor =
  object (self)
    method visit_if_then_else ~cond ~then_expr ~else_expr =
      self#visit_expr cond;
      self#visit_expr then_expr;
      Option.iter self#visit_expr else_expr
    (** Visit an if-then-else expression *)

    method visit_match ~expr ~cases:_ = self#visit_expr expr
    (** Visit a match expression *)

    method visit_try ~expr ~handlers:_ = self#visit_expr expr
    (** Visit a try expression *)

    method visit_apply ~func ~args =
      self#visit_expr func;
      List.iter self#visit_expr args
    (** Visit an apply expression *)

    method visit_let ~bindings ~body =
      List.iter (fun (_name, expr) -> self#visit_expr expr) bindings;
      self#visit_expr body
    (** Visit a let expression *)

    method visit_sequence exprs = List.iter self#visit_expr exprs
    (** Visit a sequence expression *)

    method visit_construct ~name:_ ~args = List.iter self#visit_expr args
    (** Visit a construct expression *)

    method visit_function ~params:_ ~body = self#visit_expr body
    (** Visit a function expression *)

    method visit_ident _name = ()
    (** Visit an identifier - default does nothing *)

    method visit_constant _value = ()
    (** Visit a constant - default does nothing *)

    method visit_other = ()
    (** Visit other expressions - default does nothing *)

    method visit_expr node =
      match node with
      | If_then_else { cond; then_expr; else_expr } ->
          self#visit_if_then_else ~cond ~then_expr ~else_expr
      | Match { expr; cases } -> self#visit_match ~expr ~cases
      | Try { expr; handlers } -> self#visit_try ~expr ~handlers
      | Apply { func; args } -> self#visit_apply ~func ~args
      | Let { bindings; body } -> self#visit_let ~bindings ~body
      | Sequence exprs -> self#visit_sequence exprs
      | Construct { name; args } -> self#visit_construct ~name ~args
      | Function { params; body } -> self#visit_function ~params ~body
      | Ident name -> self#visit_ident name
      | Constant value -> self#visit_constant value
      | Other -> self#visit_other
    (** Main dispatch method - calls appropriate visit method based on node type
    *)
  end

(** Function finder visitor that searches for a specific function by name *)
class function_finder_visitor target_name =
  object
    inherit visitor as super
    val mutable found_function = None
    val mutable found = false
    method get_result = found_function

    method! visit_let ~bindings ~body =
      if not found then (
        (* Check if any binding matches our target function name *)
        List.iter
          (fun (binding_name, binding_expr) ->
            if (not found) && String.equal binding_name target_name then (
              found_function <- Some binding_expr;
              found <- true))
          bindings;

        (* Continue traversal if not found yet *)
        if not found then super#visit_let ~bindings ~body)
  end

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

  (* Core merge function *)
  let merge_info acc info =
    {
      total = acc.total + info.total;
      if_then_else = acc.if_then_else + info.if_then_else;
      match_cases = acc.match_cases + info.match_cases;
      try_handlers = acc.try_handlers + info.try_handlers;
      boolean_operators = acc.boolean_operators + info.boolean_operators;
    }

  (** Complexity analysis visitor *)
  class complexity_visitor =
    object (self)
      inherit visitor as super
      val mutable info = empty
      method get_info = info
      method private add_info new_info = info <- merge_info info new_info

      method! visit_if_then_else ~cond ~then_expr ~else_expr =
        (* Record if-then-else complexity *)
        self#add_info { empty with if_then_else = 1; total = 1 };
        super#visit_if_then_else ~cond ~then_expr ~else_expr

      method! visit_match ~expr ~cases =
        (* Each match case beyond the first adds complexity *)
        let decision_points = max 0 (cases - 1) in
        self#add_info
          { empty with match_cases = decision_points; total = decision_points };
        super#visit_match ~expr ~cases

      method! visit_try ~expr ~handlers =
        (* Each exception handler adds complexity *)
        self#add_info { empty with try_handlers = handlers; total = handlers };
        super#visit_try ~expr ~handlers

      method! visit_apply ~func ~args =
        (* Check for boolean operators *)
        (match func with
        | Ident name
          when String.ends_with ~suffix:"&&" name
               || String.ends_with ~suffix:"||" name ->
            self#add_info { empty with boolean_operators = 1; total = 1 }
        | _ -> ());
        super#visit_apply ~func ~args
    end

  (** Count decision points in an AST expression node *)
  let analyze_expr node =
    let visitor = new complexity_visitor in
    visitor#visit_expr node;
    visitor#get_info

  (** Calculate cyclomatic complexity from complexity info (1 + total decision
      points) *)
  let calculate info = 1 + info.total
end

(** Nesting depth analysis using visitor pattern *)
module Nesting = struct
  class depth_visitor =
    object (self)
      inherit visitor as super
      val mutable max_depth = 0
      val mutable current_depth = 0
      method get_max_depth = max_depth

      method private enter_nesting_level =
        current_depth <- current_depth + 1;
        max_depth <- max max_depth current_depth

      method private exit_nesting_level = current_depth <- current_depth - 1

      method! visit_if_then_else ~cond ~then_expr ~else_expr =
        self#enter_nesting_level;
        super#visit_if_then_else ~cond ~then_expr ~else_expr;
        self#exit_nesting_level

      method! visit_match ~expr ~cases =
        self#enter_nesting_level;
        super#visit_match ~expr ~cases;
        self#exit_nesting_level

      method! visit_try ~expr ~handlers =
        self#enter_nesting_level;
        super#visit_try ~expr ~handlers;
        self#exit_nesting_level

      method! visit_function ~params ~body =
        self#enter_nesting_level;
        super#visit_function ~params ~body;
        self#exit_nesting_level
    end

  (** Calculate maximum nesting depth of an AST expression node *)
  let calculate_depth node =
    let visitor = new depth_visitor in
    visitor#visit_expr node;
    visitor#get_max_depth
end

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

(** Parse line indentation - counts leading spaces *)
let parse_indent line =
  let len = String.length line in
  let rec count_spaces i =
    if i < len && line.[i] = ' ' then count_spaces (i + 1) else i
  in
  count_spaces 0

(** Convert a structured name to a string *)
let name_to_string (n : name) =
  match n.prefix with
  | [] -> n.base
  | prefix -> String.concat "." prefix ^ "." ^ n.base

type token = { indent : int; content : string; loc : Location.t option }
(** Phase 1: Token type for lexing *)

(** Phase 2: Generic tree structure for indentation-based parsing *)
type 'a tree = Node of 'a * 'a tree list

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

(** Phase 2: Build indentation-based tree from tokens *)
let rec build_tree_from_tokens tokens : token tree list =
  match tokens with
  | [] -> []
  | head :: tail ->
      let current_indent = head.indent in
      (* Find all direct children (tokens with indent > current_indent but before any sibling) *)
      let rec collect_children acc remaining =
        match remaining with
        | [] -> (List.rev acc, [])
        | t :: rest ->
            if t.indent > current_indent then collect_children (t :: acc) rest
            else (List.rev acc, remaining)
      in
      let child_tokens, rest_tokens = collect_children [] tail in
      (* Recursively build subtrees for children *)
      let child_trees = build_tree_from_tokens child_tokens in
      let current_tree = Node (head, child_trees) in
      (* Continue with siblings *)
      current_tree :: build_tree_from_tokens rest_tokens

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

(** Extract node type from token content *)
let get_node_type content =
  match String.index_opt content ' ' with
  | Some idx -> String.sub content 0 idx
  | None -> content

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

(** Phase 3: Transform token tree to AST *)
let rec transform_tree_to_ast trees : t =
  List.fold_left
    (fun acc tree -> merge_ast acc (process_tree tree))
    empty_acc trees

and process_tree (Node (token, children)) : t =
  let node_type = get_node_type token.content in
  match node_type with
  | "Texp_ident" | "Pexp_ident" ->
      (* Extract identifier name from content *)
      let name =
        match extract_quoted_string token.content with
        | Some n -> parse_name n
        | None -> { prefix = []; base = token.content }
      in
      { empty_acc with identifiers = [ { name; location = token.loc } ] }
  | "Tpat_var" | "Ppat_var" ->
      (* Extract pattern variable name *)
      let name =
        match extract_quoted_string token.content with
        | Some n -> parse_name n
        | None -> { prefix = []; base = token.content }
      in
      { empty_acc with patterns = [ { name; location = token.loc } ] }
  | "Tstr_module" | "Pstr_module" ->
      (* Extract module name from next line *)
      let name =
        match children with
        | Node (child, _) :: _ -> parse_name (String.trim child.content)
        | [] -> { prefix = []; base = "Unknown" }
      in
      { empty_acc with modules = [ { name; location = token.loc } ] }
  | "Tstr_type" | "Pstr_type" ->
      (* Extract type name *)
      let child_ast = transform_tree_to_ast children in
      { empty_acc with types = child_ast.types }
  | "type_declaration" ->
      (* Extract type name from content *)
      let name =
        match extract_quoted_string token.content with
        | Some n -> parse_name n
        | None -> { prefix = []; base = token.content }
      in
      { empty_acc with types = [ { name; location = token.loc } ] }
  | _ ->
      (* Process children and merge results *)
      transform_tree_to_ast children

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

type function_structure_info = { has_pattern_match : bool; case_count : int }
(** Function structure analysis for E005 - function length detection *)

class function_structure_visitor () =
  object
    inherit visitor as super
    val mutable structure_info = { has_pattern_match = false; case_count = 0 }
    method get_info = structure_info

    method! visit_match ~expr ~cases =
      structure_info <-
        {
          has_pattern_match = true;
          case_count = structure_info.case_count + cases;
        };
      super#visit_match ~expr ~cases
  end

(** Calculate expression line count for function length analysis *)
let calculate_expr_line_count _expr =
  (* For now, return a simple default - we'll implement proper line counting later *)
  10

(** Parse typedtree text dump into AST structure using three-phase approach *)
let of_typedtree_text text =
  (* Phase 1: Lex the text into tokens *)
  let tokens = lex_text ~parse_loc_from_line:true text in
  (* Phase 2: Build indentation-based tree *)
  let trees = build_tree_from_tokens tokens in
  (* Phase 3: Transform tree to AST *)
  transform_tree_to_ast trees
