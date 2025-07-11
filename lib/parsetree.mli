(** OCamlmerlin parsetree output - focused on syntax-level analysis *)

type t = {
  has_function : bool;
  has_match : bool;
  case_count : int;
  is_data : bool; (* True if primarily data definition *)
  raw_text : string; (* Keep raw text for style/naming analysis *)
}
(** Parsetree analysis result *)

val of_json : Yojson.Safe.t -> t
(** Parse parsetree output *)

val has_pattern_matching : t -> bool
(** Check if has pattern matching *)

val has_function : t -> bool
(** Check if has function *)

val get_case_count : t -> int
(** Get case count *)

val is_data_definition : t -> bool
(** Check if primarily data definition *)

val pp : t Fmt.t
(** Pretty print *)
