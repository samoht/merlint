(** Rule filtering for merlint *)

type t
(** Rule filter configuration *)

val empty : t
(** No filtering - all rules enabled *)

val parse : string -> (t, string) result
(** Parse rule specification like "A-E110-E205"
    - A means all rules
    - E110, E205, etc. are specific error codes to disable
    - Examples:
    - "A" - enable all rules
    - "A-E110" - all rules except E110
    - "A-E110-E205" - all rules except E110 and E205 *)

val is_enabled : t -> Issue_type.t -> bool
(** Check if a specific issue type is enabled *)

val filter_issues : t -> Issue.t list -> Issue.t list
(** Filter a list of issues based on the rule configuration *)
