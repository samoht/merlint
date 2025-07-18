(** Core AST types for expression analysis *)

let src = Logs.Src.create "merlint.ast" ~doc:"AST parsing"

module Log = (val Logs.src_log src : Logs.LOG)

type name = { prefix : string list; base : string }
type elt = { name : name; location : Location.t option }

type expr =
  | Construct of { name : string; args : expr list }
  | Apply of { func : expr; args : expr list }
  | Ident of string
  | Constant of string
  | If_then_else of { cond : expr; then_expr : expr; else_expr : expr option }
  | Match of { expr : expr; cases : int }
  | Try of { expr : expr; handlers : int }
  | Function of { params : int; body : expr }
  | Let of { bindings : (string * expr) list; body : expr }
  | Sequence of expr list
  | Other

type t = {
  expressions : expr list;
  functions : (string * expr) list;
  modules : elt list;
  types : elt list;
  exceptions : elt list;
  variants : elt list;
  identifiers : elt list;
  patterns : elt list;
}

(** Generic visitor pattern for expr AST traversal *)
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

(** Convert a structured name to a string *)
let name_to_string (n : name) =
  match n.prefix with
  | [] -> n.base
  | prefix -> String.concat "." prefix ^ "." ^ n.base

(** Dialect for AST parsing *)
type dialect = Parsetree | Typedtree

exception Parse_error of string
(** Parse error exception *)

exception Type_error
(** Type error exception - raised when typedtree contains type errors *)

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
