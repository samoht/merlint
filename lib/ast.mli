(** Common AST types and utilities shared between parsetree and typedtree *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type block = { indent : int; content : string; loc : Location.t option }
(** A block is the fundamental unit, not a line *)

type dialect =
  | Parsetree
  | Typedtree
      (** AST dialect to distinguish between parsetree and typedtree formats *)

type expr_node =
  | Construct of { name : string; args : expr_node list }
      (** Constructor application like Error(...) *)
  | Apply of { func : expr_node; args : expr_node list }
      (** Function application like Fmt.str "..." 42 *)
  | Ident of string  (** Identifier like Fmt.str *)
  | Constant of string  (** Constants like strings or integers *)
  | Other  (** Other expression nodes we don't care about *)

type t = {
  identifiers : elt list;
      (** References to existing values/functions in expressions *)
  patterns : elt list;  (** New value bindings being defined *)
  modules : elt list;  (** Module definitions *)
  types : elt list;  (** Type definitions *)
  exceptions : elt list;  (** Exception definitions *)
  variants : elt list;  (** Variant constructors *)
  expressions : (expr_node * Location.t option) list;
      (** Expression trees for pattern detection (typedtree only) *)
}
(** Unified AST representation for both parsetree and typedtree *)

val extract_quoted_string : string -> string option
(** Extract quoted string from line *)

val parse_name : ?handle_bang_suffix:bool -> string -> name
(** Parse a structured name from a string like "Str.regexp" or
    "Stdlib!.Obj.magic"
    @param handle_bang_suffix
      if true, removes '!' suffix from module names (for typedtree) *)

val parse_location : string -> Location.t option
(** Parse location from string format:
    (filename[line,char+col]..filename[line,char+col]) *)

val preprocess_text : ?parse_loc_from_line:bool -> string -> block list
(** Pre-process the raw text into a list of blocks
    @param parse_loc_from_line
      if true, parse location from lines containing location patterns *)

val peek_block : block list ref -> block option
(** Helper to peek at the next block without consuming it *)

val consume_block : block list ref -> block option
(** Helper to consume the next block *)

val name_to_string : name -> string
(** Convert a structured name to a string *)

val extract_location_from_parsetree : string -> (int * int) option
(** Extract line and column from parsetree text like
    "(file.ml[2,27+16]..[2,27+25])" *)

val extract_filename_from_parsetree : string -> string
(** Extract filename from parsetree text, returns "unknown" if not found *)

val of_text : dialect:dialect -> string -> t
(** Parse AST output from raw text based on the specified dialect *)

val of_json : dialect:dialect -> filename:string -> Yojson.Safe.t -> t
(** Parse AST output from JSON with the specified dialect and filename *)

val pp : t Fmt.t
(** Pretty print the AST *)
