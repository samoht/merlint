(** E005: Function Too Long *)

type payload = { name : string; length : int; threshold : int }
(** Payload for function length issues *)

let log_src = Logs.Src.create "merlint.rules.e005" ~doc:"E005 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

type config = { max_function_length : int }

let is_test_file filename =
  let module_name =
    Filename.basename filename |> Filename.remove_extension
    |> String.lowercase_ascii
  in
  String.starts_with ~prefix:"test_" module_name
  || String.contains filename '/'
     && String.contains (Filename.dirname filename) '/'
     && List.exists
          (fun part -> part = "test")
          (String.split_on_char '/' filename)

let function_threshold config value =
  config.max_function_length
  + (value.Function_metrics.match_cases * 2)
  + value.trailing_record_fields

let metric_by_name ctx =
  Context.values ctx
  |> List.map (fun (value : Function_metrics.value) -> (value.name, value))

let issue_of_item ~config ~metrics item =
  let module Item = File_view.Item in
  match Item.kind item with
  | Item.Value ->
      let loc = File_view.Item.loc item in
      let name = File_view.Item.name item in
      let length = loc.end_.line - loc.start.line + 1 in
      let value = List.assoc_opt name metrics in
      if
        match value with
        | Some (v : Function_metrics.value) -> v.pure_data
        | None -> false
      then (
        Log.debug (fun m -> m "Skipping pure data structure: %s" name);
        None)
      else
        let threshold =
          match value with
          | Some value -> function_threshold config value
          | None -> config.max_function_length
        in
        if length <= threshold then None
        else
          Some
            (Issue.v ~loc ~severity:(length - threshold)
               { name; length; threshold })
  | _ -> None

let check (ctx : Context.file) =
  let config =
    { max_function_length = ctx.Context.config.max_function_length }
  in
  let filename = ctx.filename in
  Log.debug (fun m ->
      m "E005: Checking %s (is_test=%b)" filename (is_test_file filename));
  if is_test_file filename then []
  else
    List.filter_map
      (issue_of_item ~config ~metrics:(metric_by_name ctx))
      (File_view.items (Context.view ctx))

let pp ppf { name; length; threshold } =
  Fmt.pf ppf "Function '%s' is %d lines long (threshold: %d)" name length
    threshold

let rule =
  Rule.v ~code:"E005" ~title:"Long Functions" ~category:Complexity
    ~hint:
      "This issue means your functions are too long and hard to read. Fix them \
       by extracting logical sections into separate functions with descriptive \
       names. Note: Functions with pattern matching get additional allowance \
       (2 lines per case). Pure data structures (lists, records) are exempt \
       from length checks. For better readability, consider using helper \
       functions for complex logic. Aim for functions under 50 lines of actual \
       logic."
    ~examples:
      [ Example.bad Examples.E005.bad_ml; Example.good Examples.E005.good_ml ]
    ~pp (File check)
