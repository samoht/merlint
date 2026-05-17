(** E001: High Cyclomatic Complexity *)

type payload = { name : string; complexity : int; threshold : int }
(** Payload for complexity issues *)

type config = { max_complexity : int }

let src = Logs.Src.create "merlint.e001" ~doc:"E001 rule"

module Log = (val Logs.src_log src : Logs.LOG)

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

let check (ctx : Context.file) =
  let config = { max_complexity = ctx.Context.config.max_complexity } in
  let functions =
    Context.values ctx |> List.filter (fun v -> v.Function_metrics.is_function)
  in

  Log.debug (fun m -> m "E001: Found %d functions" (List.length functions));

  if is_test_file ctx.filename then []
  else
    List.filter_map
      (fun ({ name; loc; complexity; _ } : Function_metrics.value) ->
        if complexity > config.max_complexity then
          let loc = Loc.of_typed ~filename:ctx.filename loc in
          Some
            (Issue.v ~loc
               { name; complexity; threshold = config.max_complexity })
        else None)
      functions

let pp ppf { name; complexity; threshold } =
  Fmt.pf ppf "Function '%s' has cyclomatic complexity of %d (threshold: %d)"
    name complexity threshold

let rule =
  Rule.v ~code:"E001" ~title:"High Cyclomatic Complexity" ~category:Complexity
    ~hint:
      "High cyclomatic complexity makes code harder to understand and test. \
       Consider breaking complex functions into smaller, more focused \
       functions. Each function should ideally do one thing well."
    ~examples:
      [ Example.bad Examples.E001.bad_ml; Example.good Examples.E001.good_ml ]
    ~pp (File check)
