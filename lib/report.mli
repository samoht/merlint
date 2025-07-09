type t = {
  rule_name : string;
  passed : bool;
  issues : Issue.t list;
  file_count : int;
}

val create :
  rule_name:string -> passed:bool -> issues:Issue.t list -> file_count:int -> t

val print_status : bool -> string
val print_color : bool -> string -> string
val print_detailed : t -> unit
val print_summary : t list -> unit
val get_all_issues : t list -> Issue.t list
