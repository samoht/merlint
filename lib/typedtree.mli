(** OCamlmerlin typedtree output - focused on what we need *)

(** Expression types we care about *)
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

(** Pattern types we care about *)
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
(** Case info *)

type function_info = { cases : case list; is_function : bool }
(** Function info *)

type t = {
  has_pattern_match : bool;
  case_count : int;
  function_info : function_info option;
}
(** Typedtree analysis result *)

val of_json : Yojson.Safe.t -> t
(** Parse typedtree output *)

val has_pattern_matching : t -> bool
(** Check if has pattern matching *)

val get_case_count : t -> int
(** Get case count *)

val pp : t Fmt.t
(** Pretty print *)
