(** Legacy complexity module - all checks have been moved to rules/*.ml *)

type config = {
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
}

let default_config =
  { max_complexity = 10; max_function_length = 50; max_nesting = 3 }

(** Legacy function - complexity checks are now in E001, E005, and E010 *)
let analyze_browse_value _config _browse_result =
  (* This function is deprecated. Use E001.check, E005.check, and E010.check instead *)
  []
