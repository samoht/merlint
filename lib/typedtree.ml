(** OCamlmerlin typedtree output - focused on what we need *)

type expression_desc =
  | Texp_function
  | Texp_match
  | Texp_ifthenelse
  | Texp_while
  | Texp_for
  | Texp_try
  | Texp_let
  | Texp_apply
  | Texp_construct
  | Texp_field
  | Texp_ident
  | Texp_constant
  | Texp_record
  | Texp_array
  | Texp_tuple
  | Texp_variant
  | Texp_sequence
  | Texp_assert
  | Texp_lazy
  | Texp_send
  | Texp_new
  | Texp_instvar
  | Texp_setinstvar
  | Texp_override
  | Texp_letmodule
  | Texp_letexception
  | Texp_pack
  | Texp_open
  | Texp_unreachable
  | Texp_extension_constructor
  | Texp_hole
  | Texp_other of string

type pattern_desc =
  | Tpat_any
  | Tpat_var of string
  | Tpat_alias
  | Tpat_constant
  | Tpat_tuple
  | Tpat_construct
  | Tpat_variant
  | Tpat_record
  | Tpat_array
  | Tpat_or
  | Tpat_lazy
  | Tpat_exception
  | Tpat_other of string

type case = {
  pattern : pattern_desc;
  guard : expression_desc option;
  expression : expression_desc;
}

type function_info = { cases : case list; is_function : bool }

type t = {
  has_pattern_match : bool;
  case_count : int;
  function_info : function_info option;
}

(** Check for Tfunction_cases or Texp_match in string *)
let has_pattern_match_indicators str =
  String.contains str '\n'
  &&
  let lines = String.split_on_char '\n' str in
  List.exists
    (fun line ->
      let trimmed = String.trim line in
      String.starts_with ~prefix:"Texp_match" trimmed
      || String.starts_with ~prefix:"Tfunction_cases" trimmed)
    lines

(** Count cases in typedtree string output *)
let count_cases_in_string str =
  if String.contains str '\n' then
    let lines = String.split_on_char '\n' str in
    List.fold_left
      (fun acc line ->
        let trimmed = String.trim line in
        if String.starts_with ~prefix:"case" trimmed then acc + 1 else acc)
      0 lines
  else 0

(** Parse typedtree output - simplified for pattern matching detection *)
let of_json json =
  match json with
  | `String str ->
      {
        has_pattern_match = has_pattern_match_indicators str;
        case_count = count_cases_in_string str;
        function_info = None;
        (* Simplified for now *)
      }
  | _ -> { has_pattern_match = false; case_count = 0; function_info = None }

(** Check if has pattern matching *)
let has_pattern_matching t = t.has_pattern_match

(** Get case count *)
let get_case_count t = t.case_count

(** Pretty print *)
let pp ppf t =
  Fmt.pf ppf "{ pattern_match: %b; cases: %d }" t.has_pattern_match t.case_count
