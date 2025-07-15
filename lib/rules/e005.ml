(** E005: Function Too Long *)

type config = { max_function_length : int }

(** Calculate adjusted threshold for pattern matching functions *)
let calculate_adjusted_threshold config has_pattern case_count =
  if has_pattern then
    (* For pattern matching heavy functions, allow 2-3 lines per case *)
    let base_threshold = config.max_function_length in
    let pattern_allowance = case_count * 2 in
    max base_threshold (base_threshold + pattern_allowance)
  else config.max_function_length

(** Analyze a single value binding for function length *)
let analyze_value_binding config binding =
  match binding.Browse.ast_elt.location with
  | Some location ->
      let name_str = Ast.name_to_string binding.ast_elt.name in
      (* If name is empty, try to extract from location if possible *)
      let name = if name_str = "" then "<anonymous>" else name_str in
      let length = location.Location.end_line - location.start_line + 1 in

      (* Skip length check for non-function values that are simple data structures (lists or records) *)
      if (not binding.is_function) && binding.is_simple_list then []
        (* Simple data structures are exempt from length checks *)
      else if not binding.is_function then []
        (* Non-function values without pattern info are also exempt *)
      else
        (* Check function length - with special handling for pattern matching *)
        let adjusted_threshold =
          calculate_adjusted_threshold config
            binding.pattern_info.has_pattern_match
            binding.pattern_info.case_count
        in
        if length > adjusted_threshold then
          [
            Issue.Function_too_long
              { name; location; length; threshold = adjusted_threshold };
          ]
        else []
  | None -> []

let check config browse_data =
  let bindings = Browse.get_value_bindings browse_data in
  List.concat_map (analyze_value_binding config) bindings
