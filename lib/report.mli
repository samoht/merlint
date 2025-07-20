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

(** Create a report with the given parameters *)
val create :
  rule_name:string ->
  passed:bool ->
  issues:Rule.Run.result list ->
  file_count:int ->
  t

(** Pretty-printer for a report *)
val pp : t Fmt.t

(** Get the status string (PASS/FAIL) for the given passed state *)
val print_status : bool -> string

(** Apply color formatting to text based on passed state *)
val print_color : bool -> string -> string
val print_summary : t list -> unit
val get_all_issues : t list -> Rule.Run.result list
