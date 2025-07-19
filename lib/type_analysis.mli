(** Type signature analysis utilities *)

val is_function_type : string -> bool
(** [is_function_type signature] checks if signature represents a function type
*)

val extract_return_type : string -> string
(** [extract_return_type signature] extracts return type from function signature
*)

val count_parameters : string -> string -> int
(** [count_parameters signature param_type] counts occurrences of param_type in
    signature *)
