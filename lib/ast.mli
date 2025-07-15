(** Common AST types and utilities shared between parsetree and typedtree *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type block = { indent : int; content : string; loc : Location.t option }
(** A block is the fundamental unit, not a line *)

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

type 'acc merge_fn = 'acc -> 'acc -> 'acc
(** Generic merge accumulator function type *)

type 'acc parse_node_fn =
  block list ref -> int -> Location.t option -> 'acc -> 'acc
(** Generic parse node function type *)
