(** Report type and functions for displaying rule results. This module provides
    types and functions for creating and displaying analysis reports with visual
    feedback including color-coded status indicators and hierarchical issue
    listings. *)

type t = {
  rule_name : string;
  passed : bool;
  issues : Issue.t list;
  file_count : int;
}

val create :
  rule_name:string -> passed:bool -> issues:Issue.t list -> file_count:int -> t

val pp : t Fmt.t
(** Pretty-printer for a report *)

val pp_summary : t list Fmt.t
(** Pretty-printer for a summary of reports *)

val print_status : bool -> string
val print_color : bool -> string -> string
val print_detailed : t -> unit
val print_summary : t list -> unit
val get_all_issues : t list -> Issue.t list
