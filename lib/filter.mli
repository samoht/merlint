(** Rule filtering for merlint *)

type t
(** Rule filter configuration *)

val parse : string -> (t, string) result
(** Parse rule specification using simple format without quotes:
    - "all-E110-E205" - all rules except E110 and E205
    - "E300+E305" - only E300 and E305
    - "all-100..199" - all except error codes 100-199 *)

val is_enabled : t -> Issue.kind -> bool
(** Check if a specific issue type is enabled in the filter *)

val filter_issues : t -> Issue.t list -> Issue.t list
(** Filter a list of issues based on the rule configuration *)
