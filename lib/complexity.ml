type config = {
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
}

let default_config =
  { max_complexity = 10; max_function_length = 50; max_nesting = 3 }

(** Create issues based on thresholds *)
let create_issues config func_name location complexity length nesting
    has_pattern case_count =
  let issues = [] in

  (* Check complexity *)
  let issues =
    if complexity > config.max_complexity then
      Issue.Complexity_exceeded
        {
          name = func_name;
          location;
          complexity;
          threshold = config.max_complexity;
        }
      :: issues
    else issues
  in

  (* Check function length - with special handling for pattern matching *)
  let adjusted_threshold =
    if has_pattern then
      (* For pattern matching heavy functions, allow 2-3 lines per case *)
      let base_threshold = config.max_function_length in
      let pattern_allowance = case_count * 2 in
      max base_threshold (base_threshold + pattern_allowance)
    else config.max_function_length
  in

  let issues =
    if length > adjusted_threshold then
      Issue.Function_too_long
        { name = func_name; location; length; threshold = adjusted_threshold }
      :: issues
    else issues
  in

  (* Check nesting *)
  let issues =
    if nesting > config.max_nesting then
      Issue.Deep_nesting
        {
          name = func_name;
          location;
          depth = nesting;
          threshold = config.max_nesting;
        }
      :: issues
    else issues
  in

  issues

(** Analyze a value binding *)
let analyze_value_binding config binding =
  match (binding.Browse.name, binding.location) with
  | Some name, Some location ->
      let length = location.Location.end_line - location.start_line + 1 in
      (* For now, we can't calculate complexity/nesting from browse output alone
         TODO: Integrate with typedtree for accurate complexity calculation *)
      let complexity = 1 in
      (* Base complexity *)
      let nesting = 0 in
      (* Can't determine from browse *)
      let has_pattern = binding.pattern_info.has_pattern_match in
      let case_count = binding.pattern_info.case_count in
      create_issues config name location complexity length nesting has_pattern
        case_count
  | _ -> []

(** Main entry point - analyze browse output *)
let analyze_browse_value config browse_result =
  let bindings = Browse.get_value_bindings browse_result in
  List.concat_map (analyze_value_binding config) bindings
