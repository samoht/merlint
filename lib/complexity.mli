(** Legacy complexity module - all checks have been moved to rules/*.ml

    @deprecated
      Use individual rule modules instead:
      - E001: Cyclomatic complexity
      - E005: Function length
      - E010: Nesting depth *)

type config = {
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
}

val default_config : config

val analyze_browse_value : config -> Browse.t -> Issue.t list
(** @deprecated
      This function always returns an empty list. Use E001.check, E005.check,
      and E010.check instead. *)
