(** Report type and functions for displaying rule results. This module provides
    types and functions for creating and displaying analysis reports with visual
    feedback including color-coded status indicators and hierarchical issue
    listings. *)

type t = {
  rule_name : string;
  passed : bool;
  issues : Rule.Run.result list;
  file_count : int;
}

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are equal. Uses polymorphic
    equality. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. Uses
    polymorphic comparison. *)

val v :
  rule_name:string ->
  passed:bool ->
  issues:Rule.Run.result list ->
  file_count:int ->
  t
(** [v ~rule_name ~passed ~issues ~file_count] creates a report with the given
    parameters. *)

val pp : t Fmt.t
(** [pp fmt t] pretty prints report. *)

val print_status : bool -> string
(** [print_status passed] returns status string. *)

val print_color : bool -> string -> string
(** [print_color passed text] applies color. *)

val print_summary : t list -> unit
(** [print_summary reports] prints summary. *)

val all_issues : t list -> Rule.Run.result list
(** [all_issues reports] extracts all issues. *)
