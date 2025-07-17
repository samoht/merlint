(** E005: Function Too Long *)

type payload = { name : string; length : int; threshold : int }
(** Payload for function length issues *)

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
  | Some loc ->
      let name_str = Ast.name_to_string binding.ast_elt.name in
      (* If name is empty, try to extract from location if possible *)
      let name = if name_str = "" then "<anonymous>" else name_str in
      let length = loc.Location.end_line - loc.start_line + 1 in

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
          [ Issue.v ~loc { name; length; threshold = adjusted_threshold } ]
        else []
  | None -> []

let check (ctx : Context.file) =
  let config =
    { max_function_length = ctx.Context.config.max_function_length }
  in
  let browse_data = Context.browse ctx in

  (* Process all bindings - the analyze function handles filtering *)
  List.concat_map (analyze_value_binding config) browse_data.value_bindings

let pp ppf { name; length; threshold } =
  Fmt.pf ppf "Function '%s' is %d lines long (threshold: %d)" name length
    threshold

let rule =
  Rule.v ~code:"E005" ~title:"Long Functions" ~category:Complexity
    ~hint:
      "This issue means your functions are too long and hard to read. Fix them \
       by extracting logical sections into separate functions with descriptive \
       names. Note: Functions with pattern matching get additional allowance \
       (2 lines per case). Pure data structures (lists, records) are also \
       exempt from length checks. For better readability, consider using \
       helper functions for complex logic. Aim for functions under 50 lines of \
       actual logic."
    ~examples:[] ~pp (File check)
