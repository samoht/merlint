(** Rule filtering for merlint *)

type t
(** Rule filter configuration *)

val parse : string -> (t, string) result
(** Parse rule specification using simple format without quotes:
    - "all-E110-E205" - all rules except E110 and E205
    - "E300+E305" - only E300 and E305
    - "all-100..199" - all except error codes 100-199 *)

val is_enabled_by_code : t -> string -> bool
(** Check if a specific error code is enabled in the filter *)
